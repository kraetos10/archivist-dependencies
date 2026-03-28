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
        }
    }

    private func handleReAuthTapped(config: ServerConfig) -> Effect<Action> {
        .run { [keychainService, userService] send in
            let result = await Result {
                guard let credentials = keychainService.loadCredentials() else {
                    throw NetworkingError.missingData
                }
                // Logout first to clear stale session cookies
                try? await userService.logout(config: config)
                // Re-login to get fresh csrftoken + sessionid cookies
                _ = try await userService.login(
                    baseURL: config.baseURL,
                    port: config.port,
                    useHTTP: config.useHTTP,
                    username: credentials.username,
                    password: credentials.password
                )
                let tokenResponse = try await userService.getToken(
                    baseURL: config.baseURL,
                    port: config.port,
                    useHTTP: config.useHTTP
                )
                guard let token = tokenResponse.token else {
                    throw NetworkingError.missingData
                }
                try keychainService.save(token: token)
                return token
            }
            await send(.reAuthResult(result))
        }
    }
}
