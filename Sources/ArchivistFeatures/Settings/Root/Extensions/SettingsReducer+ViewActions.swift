import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension SettingsReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .logoutTapped:
            return .send(.didRequestLogout)
        case .rescanSubscriptionsTapped:
            state.isRescanningSubscriptions = true
            let config = state.serverConfig
            let taskService = self.taskService
            return .run { send in
                _ = try await taskService.startTask(config: config, name: TaskName.updateSubscribed.rawValue)
                await send(.rescanSubscriptionsStarted)
            } catch: { _, send in
                await send(.rescanSubscriptionsFailed)
            }
        case .pullToRefreshTriggered:
            return .send(.activeTask(.view(.startPolling)))
        case .reAuthTapped:
            state.isReAuthenticating = true
            let config = state.serverConfig
            return .run { [keychainService, userService] send in
                guard let credentials = keychainService.loadCredentials() else {
                    await send(.reAuthFailed)
                    return
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
                    await send(.reAuthFailed)
                    return
                }
                try keychainService.save(token: token)
                await send(.reAuthSucceeded(token))
            } catch: { _, send in
                await send(.reAuthFailed)
            }
        }
    }
}
