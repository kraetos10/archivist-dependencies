import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistsReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .playlistsLoaded(let response):
            return handlePlaylistsLoaded(response, state: &state)
        case .playlistsFailed:
            return handlePlaylistsFailed(state: &state)
        case .searchResultsLoaded(let playlists):
            state.searchResults = IdentifiedArrayOf(uniqueElements: playlists)
            state.isSearching = false
            return .none
        case .searchFailed:
            state.isSearching = false
            return .none
        case .addPlaylist(.presented(.subscribeSucceeded)),
             .addPlaylist(.presented(.createCustomSucceeded)):
            return handleSubscribeSucceeded(state: &state)
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handlePlaylistsLoaded(_ response: PaginatedResponse<PlaylistResponse>, state: inout State) -> Effect<Action> {
        if state.isLoading {
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

    private func handleSubscribeSucceeded(state: inout State) -> Effect<Action> {
        state.addPlaylist = nil
        return .send(.view(.pullToRefreshTriggered))
    }

    public func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
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
            do {
                let response = try await searchService.search(config: config, query: query)
                await send(.searchResultsLoaded(response.playlistResults ?? []))
            } catch {
                await send(.searchFailed)
            }
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
