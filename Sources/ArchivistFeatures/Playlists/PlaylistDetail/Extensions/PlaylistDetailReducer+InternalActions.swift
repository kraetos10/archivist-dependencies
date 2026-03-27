import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistDetailReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .playlistResult(.success(let playlist)):
            return handlePlaylistLoaded(playlist, state: &state)
        case .playlistResult(.failure):
            state.isLoadingEntries = false
            state.hasLoadedEntries = true
            return .none
        case .videoResult(.success(let (video, nextVideos))):
            return .send(.delegate(.showVideo(video, nextVideos: nextVideos)))
        case .videoResult(.failure):
            return .none
        case .removeEntryResult(.success(let videoId)):
            if var entries = state.playlist.playlistEntries {
                entries.removeAll { $0.youtubeId == videoId }
                state.playlist = state.playlist.withEntries(entries)
            }
            return .none
        case .removeEntryResult(.failure):
            return .none
        case .moveEntryResult(.failure):
            state.hasLoadedEntries = false
            return .send(.view(.viewDidAppear))
        case .moveEntryResult(.success):
            return .none
        case .thumbnailsLoaded(let thumbs):
            state.entryThumbnails.merge(thumbs) { _, new in new }
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handlePlaylistLoaded(_ playlist: PlaylistResponse, state: inout State) -> Effect<Action> {
        state.playlist = playlist
        state.isLoadingEntries = false
        state.hasLoadedEntries = true

        let entries = playlist.playlistEntries ?? []
        let entryIds = entries.compactMap(\.youtubeId).filter { state.entryThumbnails[$0] == nil }
        guard !entryIds.isEmpty else { return .none }

        let config = state.serverConfig
        return .run { [videoService] send in
            let thumbs: [String: String] = await withTaskGroup(of: (String, String?).self) { group in
                for videoId in entryIds {
                    group.addTask {
                        let video = try? await videoService.getVideo(config: config, id: videoId)
                        return (videoId, video?.vidThumbUrl)
                    }
                }
                var result: [String: String] = [:]
                for await (id, thumbUrl) in group {
                    if let thumbUrl {
                        result[id] = thumbUrl
                    }
                }
                return result
            }
            if !thumbs.isEmpty {
                await send(.thumbnailsLoaded(thumbs))
            }
        }
    }

    public func handleUnsubscribeConfirmed(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let playlistId = state.playlist.playlistId
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.deletePlaylist(config: config, id: playlistId, deleteVideos: false)
            }
            await send(.unsubscribeResult(result))
        }
    }
}
