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
                let result = await Result {
                    _ = try await taskService.startTask(config: config, name: TaskName.updateSubscribed.rawValue)
                }
                await send(.rescanSubscriptionsResult(result))
            }
        case .pullToRefreshTriggered:
            return .send(.activeTask(.view(.startPolling)))
        case .reAuthTapped:
            state.isReAuthenticating = true
            let config = state.serverConfig
            return .run { [keychainService, userService] send in
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
}
