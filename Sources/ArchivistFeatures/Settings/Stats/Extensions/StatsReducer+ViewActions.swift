import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension StatsReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        guard !state.hasLoaded, !state.isLoading else { return .none }
        state.isLoading = true
        let config = state.serverConfig
        let statsService = self.statsService
        return .merge(
            .run { send in
                let result = await Result {
                    try await statsService.getVideoStats(config: config)
                }
                await send(.videoStatsResult(result))
            },
            .run { send in
                let result = await Result {
                    try await statsService.getChannelStats(config: config)
                }
                await send(.channelStatsResult(result))
            },
            .run { send in
                let result = await Result {
                    try await statsService.getPlaylistStats(config: config)
                }
                await send(.playlistStatsResult(result))
            },
            .run { send in
                let result = await Result {
                    try await statsService.getDownloadStats(config: config)
                }
                await send(.downloadStatsResult(result))
            },
            .run { send in
                let result = await Result {
                    try await statsService.getWatchStats(config: config)
                }
                await send(.watchStatsResult(result))
            },
            .run { send in
                let result = await Result {
                    try await statsService.getBiggestChannels(config: config)
                }
                await send(.biggestChannelsResult(result))
            }
        )
    }
}
