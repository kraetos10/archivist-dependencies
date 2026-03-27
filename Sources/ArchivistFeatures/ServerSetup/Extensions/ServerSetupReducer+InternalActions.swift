import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ServerSetupReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .healthCheckSucceeded:
            return handleHealthCheckSucceeded(state: &state)
        case .healthCheckFailed:
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
            TextState(String(localized: "Could Not Connect"))
        } message: {
            TextState(String(localized: "Please check your server details and try again."))
        }
        return .none
    }
}
