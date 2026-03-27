import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistPickerReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .playlistTapped(let playlist):
            return handlePlaylistTapped(playlist, state: &state)
        }
    }

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        let config = state.serverConfig
        let videoId = state.videoId
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                let response = try await playlistService.getPlaylists(
                    config: config,
                    page: 1,
                    type: "custom",
                    channel: nil,
                    subscribed: nil
                )
                // Fetch each playlist's entries to check if video is already in it
                var playlistsContainingVideo: Set<String> = []
                await withTaskGroup(of: (String, Bool).self) { group in
                    for playlist in response.data {
                        group.addTask {
                            guard let full = try? await playlistService.getPlaylist(
                                config: config, id: playlist.playlistId
                            ) else { return (playlist.playlistId, false) }
                            let contains = full.playlistEntries?.contains { $0.youtubeId == videoId } ?? false
                            return (playlist.playlistId, contains)
                        }
                    }
                    for await (id, contains) in group where contains {
                        playlistsContainingVideo.insert(id)
                    }
                }
                return (response.data, playlistsContainingVideo)
            }
            await send(.loadResult(result))
        }
    }

    private func handlePlaylistTapped(_ playlist: PlaylistResponse, state: inout State) -> Effect<Action> {
        guard !state.isAdding, !state.alreadyInPlaylistIds.contains(playlist.playlistId) else { return .none }
        state.isAdding = true
        let config = state.serverConfig
        let playlistId = playlist.playlistId
        let videoId = state.videoId
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.modifyCustomPlaylist(
                    config: config,
                    id: playlistId,
                    action: "create",
                    videoId: videoId
                )
            }
            await send(.addResult(result))
        }
    }
}
