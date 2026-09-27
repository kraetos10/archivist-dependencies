import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistPickerReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            guard !state.isLoading, state.playlists.isEmpty else { return .none }
            state.isLoading = true
            return fetchPage(1, state: state)
        case .lastItemAppeared:
            guard state.currentPage < state.lastPage,
                  !state.isLoading,
                  !state.isLoadingMore else { return .none }
            state.isLoadingMore = true
            return fetchPage(state.currentPage + 1, state: state)
        case .playlistTapped(let playlist):
            return handlePlaylistTapped(playlist, state: &state)
        }
    }

    /// Fetches one page of custom playlists, then checks which of them
    /// already hold the video — at most `membershipCheckConcurrency` at a
    /// time.
    private func fetchPage(
        _ page: Int,
        state: State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.videoId
        let playlistService = self.playlistService
        let limit = Self.membershipCheckConcurrency
        return .run { send in
            let result = await Result {
                let response = try await playlistService.getPlaylists(
                    config: config,
                    page: page,
                    type: "custom",
                    channel: nil,
                    subscribed: nil
                )
                let contains: @Sendable (String) async -> (String, Bool) = { playlistId in
                    guard let full = try? await playlistService.getPlaylist(
                        config: config,
                        id: playlistId
                    ) else { return (playlistId, false) }
                    let holdsVideo = full.playlistEntries?.contains { $0.youtubeId == videoId } ?? false
                    return (playlistId, holdsVideo)
                }
                var containing: Set<String> = []
                await withTaskGroup(of: (String, Bool).self) { group in
                    var pending = response.data.map(\.playlistId)[...]
                    for _ in 0..<min(limit, pending.count) {
                        if let id = pending.popFirst() {
                            group.addTask { await contains(id) }
                        }
                    }
                    while let checked = await group.next() {
                        let (id, holdsVideo) = checked
                        if holdsVideo {
                            containing.insert(id)
                        }
                        if let next = pending.popFirst() {
                            group.addTask { await contains(next) }
                        }
                    }
                }
                return Page(
                    playlists: response.data,
                    containingVideo: containing,
                    currentPage: response.paginate.currentPage,
                    lastPage: response.paginate.lastPage
                )
            }
            await send(.loadResult(result))
        }
    }

    private func handlePlaylistTapped(
        _ playlist: PlaylistResponse,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isAdding, !state.isAlreadyAdded(playlist) else { return .none }
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
