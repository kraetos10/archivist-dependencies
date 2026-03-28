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
            return handleOnAppear(state: &state)
        case .pullToRefreshTriggered:
            return handleRefreshTriggered(state: &state)
        case .lastItemAppeared:
            return handleLoadNextPage(state: &state)
        case .videoTapped(let video):
            return .send(.delegate(.videoSelected(video)))
        }
    }

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        guard !state.hasLoaded else { return .none }
        state.isLoading = true
        return fetchAll(config: state.serverConfig, watchedPage: 1)
    }

    private func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.currentPage = 1
        return fetchAll(config: state.serverConfig, watchedPage: 1)
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage, !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        let nextPage = state.currentPage + 1
        let config = state.serverConfig
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: nextPage,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: "watched",
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.watchedVideosResult(result))
        }
    }

    private func fetchAll(
        config: ServerConfig,
        watchedPage: Int
    ) -> Effect<Action> {
        let videoService = self.videoService
        return .merge(
            .run { send in
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
            },
            .run { send in
                let result = await Result {
                    try await videoService.getVideos(
                        config: config,
                        page: watchedPage,
                        sort: "published",
                        order: "desc",
                        type: nil,
                        watch: "watched",
                        channel: nil,
                        playlist: nil
                    )
                }
                await send(.watchedVideosResult(result))
            }
        )
    }
}
