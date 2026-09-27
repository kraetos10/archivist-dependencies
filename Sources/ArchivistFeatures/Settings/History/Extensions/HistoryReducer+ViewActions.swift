import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension HistoryReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            guard !state.hasLoaded, !state.isLoading else { return .none }
            return handleRefresh(state: &state)
        case .pullToRefreshTriggered:
            return handleRefresh(state: &state)
        case .itemAppeared(let id):
            guard id == state.watchedVideos.last?.id else { return .none }
            return handleLoadNextPage(state: &state)
        case .videoTapped(let video):
            return .send(.delegate(.videoSelected(video)))
        }
    }

    // MARK: - Private Handlers

    /// Reloads both lists from the top, superseding any page in flight.
    private func handleRefresh(state: inout State) -> Effect<Action> {
        state.isLoadingContinue = true
        state.isLoadingWatched = true
        state.isLoadingMore = false
        state.currentPage = 1
        return .merge(
            fetchContinueVideos(config: state.serverConfig),
            fetchWatchedVideos(config: state.serverConfig, page: 1)
        )
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage,
              !state.isLoadingMore,
              !state.isLoadingWatched else { return .none }
        state.isLoadingMore = true
        return fetchWatchedVideos(config: state.serverConfig, page: state.currentPage + 1)
    }

    private func fetchContinueVideos(config: ServerConfig) -> Effect<Action> {
        .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: "continue",
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.continueVideosResult(result))
        }
        .cancellable(id: CancelID.continueVideos, cancelInFlight: true)
    }

    private func fetchWatchedVideos(
        config: ServerConfig,
        page: Int
    ) -> Effect<Action> {
        .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: page,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: "watched",
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.watchedVideosResult(page: page, result))
        }
        .cancellable(id: CancelID.watchedVideos, cancelInFlight: true)
    }
}
