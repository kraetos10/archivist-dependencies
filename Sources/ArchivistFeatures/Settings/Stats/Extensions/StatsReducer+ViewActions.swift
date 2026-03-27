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
                if let result = try? await statsService.getVideoStats(config: config) {
                    await send(.videoStatsLoaded(result))
                } else {
                    await send(.statsFailed(.video))
                }
            },
            .run { send in
                if let result = try? await statsService.getChannelStats(config: config) {
                    await send(.channelStatsLoaded(result))
                } else {
                    await send(.statsFailed(.channel))
                }
            },
            .run { send in
                if let result = try? await statsService.getPlaylistStats(config: config) {
                    await send(.playlistStatsLoaded(result))
                } else {
                    await send(.statsFailed(.playlist))
                }
            },
            .run { send in
                if let result = try? await statsService.getDownloadStats(config: config) {
                    await send(.downloadStatsLoaded(result))
                } else {
                    await send(.statsFailed(.download))
                }
            },
            .run { send in
                if let result = try? await statsService.getWatchStats(config: config) {
                    await send(.watchStatsLoaded(result))
                } else {
                    await send(.statsFailed(.watch))
                }
            },
            .run { send in
                if let result = try? await statsService.getBiggestChannels(config: config) {
                    await send(.biggestChannelsLoaded(result))
                } else {
                    await send(.statsFailed(.biggestChannels))
                }
            }
        )
    }
}
