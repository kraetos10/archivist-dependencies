import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension LoginReducer {
    func handlePingResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        switch result {
        case .success:
            return handlePingSucceeded(state: &state)
        case .failure(let error):
            return handlePingFailed(error, state: &state)
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
