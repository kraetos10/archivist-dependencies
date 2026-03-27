import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistsReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleOnAppear(state: &state)
        case .pullToRefreshTriggered:
            return handleRefreshTriggered(state: &state)
        case .lastItemAppeared:
            return handleLoadNextPage(state: &state)
        case .playlistCardTapped(let playlist):
            return handlePlaylistCardTapped(playlist, state: &state)
        case .addPlaylistTapped:
            return handleAddPlaylistTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        guard state.playlists.isEmpty, !state.isLoading else { return .none }
        state.isLoading = true
        return fetchPlaylists(config: state.serverConfig, page: 1)
    }

    private func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.currentPage = 1
        return fetchPlaylists(config: state.serverConfig, page: 1)
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage, !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        let nextPage = state.currentPage + 1
        return fetchPlaylists(config: state.serverConfig, page: nextPage)
    }

    private func handlePlaylistCardTapped(_ playlist: PlaylistResponse, state: inout State) -> Effect<Action> {
        if state.useSplitView {
            guard state.selectedPlaylist?.playlist.playlistId != playlist.playlistId else {
                return .none
            }
        }
        let detailState = PlaylistDetailReducer.State(
            serverConfig: state.serverConfig,
            playlist: playlist
        )
        state.selectedPlaylist = detailState
        if !state.useSplitView {
            state.path.append(.playlistDetail(detailState))
        }
        return .none
    }

    private func handleAddPlaylistTapped(state: inout State) -> Effect<Action> {
        state.addPlaylist = AddPlaylistReducer.State(serverConfig: state.serverConfig)
        return .none
    }

    func fetchPlaylists(config: ServerConfig, page: Int) -> Effect<Action> {
        let playlistService = self.playlistService
        return .run { send in
            do {
                let response = try await playlistService.getPlaylists(
                    config: config,
                    page: page,
                    type: nil,
                    channel: nil,
                    subscribed: nil
                )
                await send(.playlistsLoaded(response))
            } catch {
                await send(.playlistsFailed(error))
            }
        }
    }
}
