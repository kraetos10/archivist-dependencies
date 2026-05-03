import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension FilteredVideoListReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .pullToRefreshTriggered:
            return handlePullToRefreshTriggered(state: &state)
        case .lastItemAppeared:
            return handleLastItemAppeared(state: &state)
        case .videoTapped(let video):
            return .send(.delegate(.videoSelected(video)))
        case .sortOrderChanged(let sort):
            return handleSortOrderChanged(sort, state: &state)
        case .playNextTapped(let video):
            return .send(.delegate(.playNextRequested(video)))
        case .addToPlaylistTapped(let video):
            return .send(.delegate(.addToPlaylistRequested(video)))
        case .downloadToDeviceTapped(let video):
            return .send(.delegate(.downloadToDeviceRequested(video)))
        case .deleteFromDeviceTapped(let video):
            return .send(.delegate(.deleteFromDeviceRequested(video)))
        case .markAsWatchedTapped(let video):
            return .send(.delegate(.markAsWatchedRequested(video)))
        case .deleteFromServerTapped(let video):
            return .send(.delegate(.deleteFromServerRequested(video)))
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        guard !state.hasLoaded, !state.isLoading else { return .none }
        return fetchPage(1, state: &state)
    }

    private func handlePullToRefreshTriggered(state: inout State) -> Effect<Action> {
        state.videos = []
        state.currentPage = 1
        state.lastPage = 1
        state.hasLoaded = false
        return fetchPage(1, state: &state)
    }

    private func handleLastItemAppeared(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage,
              !state.isLoading,
              !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        return fetchPage(state.currentPage + 1, state: &state)
    }

    private func handleSortOrderChanged(
        _ sort: VideoSortOrder,
        state: inout State
    ) -> Effect<Action> {
        guard sort != state.sortOrder else { return .none }
        state.$sortOrder.withLock { $0 = sort }
        state.videos = []
        state.currentPage = 1
        state.lastPage = 1
        state.hasLoaded = false
        return fetchPage(1, state: &state)
    }

    func fetchPage(
        _ page: Int,
        state: inout State
    ) -> Effect<Action> {
        if page == 1 { state.isLoading = true }
        let config = state.serverConfig
        let sort = state.sortOrder.apiValue
        let watch = state.filter.apiValue
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: page,
                    sort: sort,
                    order: "desc",
                    type: nil,
                    watch: watch,
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }
}
