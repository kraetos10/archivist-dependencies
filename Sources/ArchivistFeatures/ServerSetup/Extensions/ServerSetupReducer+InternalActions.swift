import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ServerSetupReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .healthCheckResult(.success):
            return handleHealthCheckSucceeded(state: &state)
        case .healthCheckResult(.failure):
            return handleHealthCheckFailed(state: &state)
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleHealthCheckSucceeded(state: inout State) -> Effect<Action> {
        state.isLoading = false
        return .send(.serverValidated)
    }

    private func handleHealthCheckFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.alert = AlertState {
            TextState(String.localised("login.couldNotConnect", table: .login))
        } message: {
            TextState(String.localised("login.checkDetails", table: .login))
        }
        return .none
    }
}
