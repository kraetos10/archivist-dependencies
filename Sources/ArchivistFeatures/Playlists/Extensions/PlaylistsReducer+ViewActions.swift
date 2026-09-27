import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistsReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleOnAppear(state: &state)
        case .splitViewDidAppear:
            return handleSplitViewDidAppear(state: &state)
        case .pullToRefreshTriggered:
            return refreshPlaylists(state: &state)
        case .lastItemAppeared:
            return handleLoadNextPage(state: &state)
        case .playlistCardTapped(let playlist):
            return handlePlaylistCardTapped(playlist, state: &state)
        case .addPlaylistTapped:
            return handleAddPlaylistTapped(state: &state)
        }
    }

    // MARK: - Shared

    /// Reloads the first page. Cancels any page still in flight, so a late
    /// page can't be mistaken for, or appended ahead of, the fresh list.
    func refreshPlaylists(state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.currentPage = 1
        return fetchPlaylists(config: state.serverConfig, page: 1)
            .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        guard state.playlists.isEmpty, !state.isLoading else { return .none }
        state.isLoading = true
        return fetchPlaylists(config: state.serverConfig, page: 1)
            .cancellable(id: CancelID.load)
    }

    /// The split view never shows `path`; move anything pushed before it
    /// first appeared into the selection.
    private func handleSplitViewDidAppear(state: inout State) -> Effect<Action> {
        state.useSplitView = true
        if state.selectedPlaylist == nil,
           case .playlistDetail(let detail)? = state.path.last {
            state.selectedPlaylist = detail
        }
        state.path.removeAll()
        return handleOnAppear(state: &state)
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage,
              !state.isLoadingMore,
              !state.isLoading else { return .none }
        state.isLoadingMore = true
        let nextPage = state.currentPage + 1
        return fetchPlaylists(config: state.serverConfig, page: nextPage)
            .cancellable(id: CancelID.load)
    }

    private func handlePlaylistCardTapped(
        _ playlist: PlaylistResponse,
        state: inout State
    ) -> Effect<Action> {
        let detailState = PlaylistDetailReducer.State(
            serverConfig: state.serverConfig,
            playlist: playlist
        )
        if state.useSplitView {
            guard state.selectedPlaylist?.playlist.playlistId != playlist.playlistId else {
                return .none
            }
            state.selectedPlaylist = detailState
        } else {
            state.path.append(.playlistDetail(detailState))
        }
        return .none
    }

    private func handleAddPlaylistTapped(state: inout State) -> Effect<Action> {
        state.addPlaylist = AddPlaylistReducer.State(serverConfig: state.serverConfig)
        return .none
    }

    private func fetchPlaylists(
        config: ServerConfig,
        page: Int
    ) -> Effect<Action> {
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.getPlaylists(
                    config: config,
                    page: page,
                    type: nil,
                    channel: nil,
                    subscribed: nil
                )
            }
            await send(.playlistsResult(result))
        }
    }
}
