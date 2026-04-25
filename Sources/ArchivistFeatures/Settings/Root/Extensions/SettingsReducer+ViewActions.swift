import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension SettingsReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .logoutTapped:
            return .send(.didRequestLogout)
        case .rescanSubscriptionsTapped:
            state.isRescanningSubscriptions = true
            let config = state.serverConfig
            let taskService = self.taskService
            return .run { send in
                let result = await Result {
                    _ = try await taskService.startTask(config: config, name: TaskName.updateSubscribed.rawValue)
                }
                await send(.rescanSubscriptionsResult(result))
            }
        case .pullToRefreshTriggered:
            return .send(.activeTask(.view(.startPolling)))
        case .reAuthTapped:
            state.isReAuthenticating = true
            return handleReAuthTapped(config: state.serverConfig)
        case .downloadsTapped:
            state.path.append(
                .downloads(DownloadsReducer.State(serverConfig: state.serverConfig))
            )
            return .none
        case .statsTapped:
            state.path.append(
                .stats(StatsReducer.State(serverConfig: state.serverConfig))
            )
            return .none
        #if !os(tvOS)
        case .deviceDownloadsTapped:
            state.path.append(
                .deviceDownloads(DeviceDownloadsReducer.State(serverConfig: state.serverConfig))
            )
            return .none
        #endif
        case .historyTapped:
            state.path.append(
                .history(HistoryReducer.State(serverConfig: state.serverConfig))
            )
            return .none
        #if !os(watchOS)
        case .playbackCacheTapped:
            state.path.append(.playbackCache(PlaybackCacheReducer.State()))
            return .none
        #endif
        #if !os(tvOS)
        case .thirdPartyLibrariesTapped:
            state.path.append(.thirdPartyLibraries(ThirdPartyLibrariesReducer.State()))
            return .none
        #endif
        }
    }

    private func handleReAuthTapped(config: ServerConfig) -> Effect<Action> {
        // With API-key auth there is no username/password to re-login with.
        // If the current token has stopped working the user must log out and
        // paste a new API key. Surface that by triggering logout.
        _ = config
        return .send(.didRequestLogout)
    }
}
