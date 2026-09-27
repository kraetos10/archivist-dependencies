import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistsReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .playlistsResult(.success(let response)):
            return handlePlaylistsLoaded(response, state: &state)
        case .playlistsResult(.failure):
            return handlePlaylistsFailed(state: &state)
        case .searchResult(.success(let playlists)):
            state.searchResults = IdentifiedArrayOf(uniqueElements: playlists)
            state.isSearching = false
            return .none
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .addPlaylist(.presented(.delegate(.didAdd))):
            // AddPlaylist dismisses itself; the list picks up the new one.
            return refreshPlaylists(state: &state)
        case .playlistDetail(.presented(.delegate(.didUnsubscribe(let playlistId)))):
            state.playlists.remove(id: playlistId)
            state.selectedPlaylist = nil
            return .none
        case .path(.element(id: let id, action: .playlistDetail(.delegate(.didUnsubscribe(let playlistId))))):
            state.playlists.remove(id: playlistId)
            state.path.pop(from: id)
            return .none
        case .path(.element(_, action: .playlistDetail(.delegate(
                .showVideo(let video, let nextVideos, let loopVideoIds)
             )))),
             .playlistDetail(.presented(.delegate(
                .showVideo(let video, let nextVideos, let loopVideoIds)
             ))):
            state.videoDetail = VideoDetailReducer.State(
                serverConfig: state.serverConfig,
                video: video,
                nextVideos: nextVideos,
                loopVideoIds: loopVideoIds,
                shouldAutoPlayNextVideo: state.autoPlayPlaylist
            )
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handlePlaylistsLoaded(
        _ response: PaginatedResponse<PlaylistResponse>,
        state: inout State
    ) -> Effect<Action> {
        if response.paginate.currentPage <= 1 {
            state.playlists = IdentifiedArrayOf(uniqueElements: response.data)
        } else {
            for playlist in response.data {
                state.playlists.updateOrAppend(playlist)
            }
        }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }

    func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.searchResults = []
            state.isSearching = false
            return .cancel(id: CancelID.search)
        }
        state.isSearching = true
        let config = state.serverConfig
        let clock = self.clock
        let searchService = self.searchService
        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            let result = await Result {
                try await searchService.search(config: config, query: query)
            }
            await send(.searchResult(result.map { $0.playlistResults ?? [] }))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func handlePlaylistsFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }
}
