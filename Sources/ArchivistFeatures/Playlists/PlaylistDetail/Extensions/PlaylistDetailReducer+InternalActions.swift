import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistDetailReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .playlistResult(.success(let playlist)):
            return handlePlaylistLoaded(playlist, state: &state)
        case .playlistResult(.failure):
            state.isLoadingEntries = false
            state.hasLoadedEntries = true
            return .none
        case .videoResult(.success(let (video, nextVideos))):
            return .send(.delegate(.showVideo(
                video,
                nextVideos: nextVideos,
                loopVideoIds: state.loopVideoIds
            )))
        case .videoResult(.failure):
            state.alert = .failure(String.localised("playlist.playFailed", table: .videos))
            return .none
        case .removeEntryResult(.success(let videoId)):
            var entries = state.entries
            entries.removeAll { $0.youtubeId == videoId }
            state.playlist = state.playlist.withEntries(entries)
            return .none
        case .removeEntryResult(.failure):
            state.alert = .failure(String.localised("playlist.removeEntryFailed", table: .videos))
            return .none
        case .setWatchedResult(.success):
            return .none
        case .setWatchedResult(.failure):
            state.alert = .failure(String.localised("video.setWatchedFailed", table: .videos))
            return .none
        case .serverDownloadResult(.success):
            return .none
        case .serverDownloadResult(.failure):
            state.alert = .failure(String.localised("video.queueDownloadFailed", table: .videos))
            return .none
        case .unsubscribeResult(.success):
            return .send(.delegate(.didUnsubscribe(state.playlist.playlistId)))
        case .unsubscribeResult(.failure):
            state.alert = .failure(String.localised("playlist.unsubscribeFailed", table: .videos))
            return .none
        case .thumbnailsLoaded(let thumbs, let availableIDs):
            state.entryThumbnails.merge(thumbs) { _, new in new }
            state.availableVideoIDs.formUnion(availableIDs)
            return .none
        default:
            return .none
        }
    }

    // MARK: - Loading

    func loadPlaylist(state: inout State) -> Effect<Action> {
        state.isLoadingEntries = true
        let config = state.serverConfig
        let playlistId = state.playlist.playlistId
        return .run { [playlistService] send in
            let result = await Result {
                try await playlistService.getPlaylist(
                    config: config,
                    id: playlistId
                )
            }
            await send(.playlistResult(result))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    /// Reload after something changed the playlist on the server.
    func reloadPlaylist(state: inout State) -> Effect<Action> {
        state.hasLoadedEntries = false
        return loadPlaylist(state: &state)
    }

    // MARK: - Private Handlers

    private func handlePlaylistLoaded(
        _ playlist: PlaylistResponse,
        state: inout State
    ) -> Effect<Action> {
        state.playlist = playlist
        state.isLoadingEntries = false
        state.hasLoadedEntries = true

        let entries = playlist.playlistEntries ?? []
        let entryIds = entries.compactMap(\.youtubeId).filter {
            state.entryThumbnails[$0] == nil
        }

        guard !entryIds.isEmpty else { return .none }
        return fetchEntryDetails(entryIds, config: state.serverConfig)
    }

    /// Looks each entry up to learn whether the server has it (and its
    /// thumbnail). At most `thumbnailFetchConcurrency` requests are in
    /// flight at once — a long playlist mustn't open hundreds of
    /// connections — and a reload cancels a lookup still running.
    private func fetchEntryDetails(
        _ entryIds: [String],
        config: ServerConfig
    ) -> Effect<Action> {
        let videoService = self.videoService
        let limit = Self.thumbnailFetchConcurrency
        return .run { send in
            let lookup: @Sendable (String) async -> (String, String?, Bool) = { videoId in
                let video = try? await videoService.getVideo(
                    config: config,
                    id: videoId
                )
                return (videoId, video?.vidThumbUrl, video != nil)
            }
            var thumbs: [String: String] = [:]
            var available: Set<String> = []

            await withTaskGroup(of: (String, String?, Bool).self) { group in
                var pending = entryIds[...]
                for _ in 0..<min(limit, pending.count) {
                    if let videoId = pending.popFirst() {
                        group.addTask { await lookup(videoId) }
                    }
                }
                while let result = await group.next() {
                    let (id, thumbUrl, exists) = result
                    if let thumbUrl {
                        thumbs[id] = thumbUrl
                    }
                    if exists {
                        available.insert(id)
                    }
                    if !Task.isCancelled, let videoId = pending.popFirst() {
                        group.addTask { await lookup(videoId) }
                    }
                }
            }
            guard !Task.isCancelled else { return }
            await send(.thumbnailsLoaded(thumbs, availableIDs: available))
        }
        .cancellable(id: CancelID.thumbnails, cancelInFlight: true)
    }

    func handleUnsubscribeConfirmed(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let playlistId = state.playlist.playlistId
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.deletePlaylist(
                    config: config,
                    id: playlistId,
                    deleteVideos: false
                )
            }
            await send(.unsubscribeResult(result))
        }
    }

    func handleServerDownloadConfirmed(
        _ videoId: String,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let items = [AddDownloadItem(youtubeId: videoId, status: "pending")]
        let downloadService = self.downloadService
        return .run { send in
            let result = await Result {
                try await downloadService.addDownloads(
                    config: config,
                    items: items,
                    autostart: true,
                    flat: false,
                    force: false
                )
            }
            await send(.serverDownloadResult(result.map { videoId }))
        }
    }
}

extension AlertState where Action == PlaylistDetailReducer.AlertAction {
    /// An error alert with just an OK button.
    static func failure(_ message: String) -> Self {
        AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(message)
        }
    }
}
