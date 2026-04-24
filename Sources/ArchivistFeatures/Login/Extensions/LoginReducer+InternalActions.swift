import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension LoginReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .pingResult(.success):
            return handlePingSucceeded(state: &state)
        case .pingResult(.failure(let error)):
            return handlePingFailed(error, state: &state)
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handlePingSucceeded(state: inout State) -> Effect<Action> {
        state.isLoading = false
        return .send(.loginSucceeded(state.apiToken))
    }

    private func handlePingFailed(
        _ error: Error,
        state: inout State
    ) -> Effect<Action> {
        state.isLoading = false
        if let networkError = error as? NetworkingError,
           case .errorStatusCode(let code, _) = networkError,
           code == 401 || code == 403 {
            state.alert = AlertState {
                TextState(String.localised("login.loginFailed", table: .login))
            } message: {
                TextState(String.localised("login.invalidApiKey", table: .login))
            }
        } else {
            state.alert = AlertState {
                TextState(String.localised("login.couldNotConnect", table: .login))
            } message: {
                TextState(String.localised("login.checkDetails", table: .login))
            }
        }
        return .none
    }
}
