import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistDetailReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .entryTapped(let entry):
            return handleEntryTapped(entry, state: &state)
        case .unsubscribeTapped:
            return handleUnsubscribeTapped(state: &state)
        case .removeEntryTapped(let entry):
            return handleRemoveEntryTapped(entry, state: &state)
        case .addVideoTapped:
            state.videoPicker = VideoPickerReducer.State(
                serverConfig: state.serverConfig,
                playlistId: state.playlist.playlistId
            )
            return .none
        case .downloadToDeviceTapped(let entry):
            return handleDownloadToDeviceTapped(entry, state: &state)
        case .markAsWatchedTapped(let entry):
            return handleMarkAsWatchedTapped(entry, state: &state)
        case .loopToggled:
            state.$loopPlaylistEnabled.withLock { $0.toggle() }
            return .none
        case .descriptionTapped:
            state.isShowingFullDescription = true
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        guard !state.hasLoadedEntries, !state.isLoadingEntries else { return .none }
        return loadPlaylist(state: &state)
    }

    private func handleUnsubscribeTapped(state: inout State) -> Effect<Action> {
        let playlistName = state.playlist.playlistName
        state.alert = AlertState {
            TextState(String.localised("video.removePlaylist", table: .videos))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: .confirmUnsubscribe) {
                TextState(String.localised("generic.remove", table: .generic))
            }
        } message: {
            TextState(
                String.localised(
                    "playlist.removeConfirm \(playlistName)",
                    table: .videos
                )
            )
        }
        return .none
    }

    /// An entry the server has plays; one it hasn't downloaded yet offers
    /// to queue it instead.
    private func handleEntryTapped(
        _ entry: PlaylistEntry,
        state: inout State
    ) -> Effect<Action> {
        guard let videoId = entry.youtubeId else { return .none }
        guard state.isEntryAvailable(entry) else {
            return handleUnavailableEntryTapped(
                entry,
                videoId: videoId,
                state: &state
            )
        }
        let config = state.serverConfig
        let entries = state.entries
        let tappedIndex = entries.firstIndex(where: { $0.youtubeId == videoId })
        let nextEntryIds: [String] = {
            guard let idx = tappedIndex else { return [] }
            return entries.suffix(from: entries.index(after: idx)).compactMap(\.youtubeId)
        }()
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                let video = try await videoService.getVideo(config: config, id: videoId)
                let nextVideos: [VideoResponse] = await withTaskGroup(of: VideoResponse?.self) { group in
                    for nextId in nextEntryIds.prefix(10) {
                        group.addTask {
                            try? await videoService.getVideo(config: config, id: nextId)
                        }
                    }
                    var results: [(Int, VideoResponse)] = []
                    for await result in group {
                        if let video = result,
                           let order = nextEntryIds.firstIndex(of: video.videoId) {
                            results.append((order, video))
                        }
                    }
                    return results.sorted { $0.0 < $1.0 }.map(\.1)
                }
                return (video, nextVideos: nextVideos)
            }
            await send(.videoResult(result))
        }
        .cancellable(id: CancelID.openEntry, cancelInFlight: true)
    }

    private func handleUnavailableEntryTapped(
        _ entry: PlaylistEntry,
        videoId: String,
        state: inout State
    ) -> Effect<Action> {
        state.alert = AlertState {
            TextState(entry.title ?? videoId)
        } actions: {
            ButtonState(action: .confirmServerDownload(videoId)) {
                TextState(String.localised("video.downloadNow", table: .videos))
            }
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
        } message: {
            TextState(String.localised("playlist.serverDownloadPrompt", table: .videos))
        }
        return .none
    }

    private func handleRemoveEntryTapped(
        _ entry: PlaylistEntry,
        state: inout State
    ) -> Effect<Action> {
        guard let videoId = entry.youtubeId, state.isCustomPlaylist else { return .none }
        let config = state.serverConfig
        let playlistId = state.playlist.playlistId
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.modifyCustomPlaylist(
                    config: config,
                    id: playlistId,
                    action: "remove",
                    videoId: videoId
                )
            }
            await send(.removeEntryResult(result.map { videoId }), animation: .default)
        }
    }

    private func handleDownloadToDeviceTapped(
        _ entry: PlaylistEntry,
        state: inout State
    ) -> Effect<Action> {
        guard let videoId = entry.youtubeId else { return .none }
        let config = state.serverConfig
        let createdAt = now.timeIntervalSince1970
        return .run { [videoService, deviceDownloadDatabase, persistentDownloadManager] _ in
            let video = try await videoService.getVideo(config: config, id: videoId)
            guard let mediaPath = video.mediaUrl,
                  let mediaURL = config.fullURL(for: mediaPath) else { return }

            let download = DeviceDownload(
                id: videoId,
                title: video.title,
                channelName: video.channelName,
                thumbUrl: video.vidThumbUrl,
                status: .downloading,
                progress: 0,
                fileSize: video.mediaSize,
                createdAt: createdAt
            )
            try? deviceDownloadDatabase.insertDownload(download)

            await persistentDownloadManager.startDownload(
                url: mediaURL,
                videoId: videoId,
                title: video.title,
                expectedSize: video.mediaSize.map { Int64($0) },
                authHeaders: config.authHeaders,
                thumbnailURL: video.vidThumbUrl.flatMap { config.fullURL(for: $0) }
            )
        }
    }

    /// Marks the video watched on the server. (This used to post a
    /// progress of 0, which reset the resume position and left the video
    /// unwatched.)
    private func handleMarkAsWatchedTapped(
        _ entry: PlaylistEntry,
        state: inout State
    ) -> Effect<Action> {
        guard let videoId = entry.youtubeId else { return .none }
        let config = state.serverConfig
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                try await videoService.setWatched(
                    config: config,
                    videoId: videoId,
                    isWatched: true
                )
            }
            await send(.setWatchedResult(result.map { videoId }))
        }
    }
}
