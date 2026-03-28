import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension SettingsReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .activeTask(.downloadCompleted):
            // If the Downloads screen is currently on the stack, trigger a refresh
            // on the topmost entry that is a downloads screen.
            for (id, element) in zip(state.path.ids, state.path) {
                if case .downloads = element {
                    return .send(.path(.element(id: id, action: .downloads(.view(.pullToRefreshTriggered)))))
                }
            }
            return .none
        case .rescanSubscriptionsResult(.success):
            state.isRescanningSubscriptions = false
            return .send(.activeTask(.view(.startPolling)))
        case .rescanSubscriptionsResult(.failure):
            state.isRescanningSubscriptions = false
            return .none
        case .videoDetail:
            return .none
        case .reAuthResult(.success(let token)):
            state.isReAuthenticating = false
            state.serverConfig = ServerConfig(
                baseURL: state.serverConfig.baseURL,
                port: state.serverConfig.port,
                apiToken: token,
                useHTTP: state.serverConfig.useHTTP
            )
            return .send(.didRefreshToken(token))
        case .reAuthResult(.failure(let error)):
            state.isReAuthenticating = false
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(error.localizedDescription)
            }
            return .none
        case .didRequestLogout, .activeTask:
            return .none
        default:
            return .none
        }
    }
}
