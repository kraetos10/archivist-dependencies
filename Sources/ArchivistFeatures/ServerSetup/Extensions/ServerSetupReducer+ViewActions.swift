import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension ServerSetupReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .nextButtonTapped:
            return handleNextButtonTapped(state: &state)
        }
    }

    /// The child-mode switch moved. Turning it on asks for a PIN first;
    /// turning it off clears the stored one.
    func handleChildModeToggled(state: inout State) -> Effect<Action> {
        if state.childModeToggle {
            guard !state.childModeEnabled else { return .none }
            state.pinSetup = ChildPinSetupReducer.State()
            return .none
        }
        guard state.childModeEnabled else { return .none }
        return .run { [pinStore] send in
            await send(.childModeSaveResult(Result {
                try pinStore.clear()
                return false
            }))
        }
    }

    // MARK: - Private Handlers

    private func handleNextButtonTapped(state: inout State) -> Effect<Action> {
        // The button stays focusable while the health check runs, so
        // ignore repeat presses here.
        guard !state.isLoading,
              !state.registrationDetails.serverAddress.isEmpty else {
            return .none
        }
        state.isLoading = true
        let serverURL = state.registrationDetails.serverAddress
        let port = Int(state.registrationDetails.port)
        let useHTTP = state.registrationDetails.useHTTP
        return .run { [healthService, localNetworkPrompt] send in
            localNetworkPrompt.trigger()
            let result = await Result {
                try await healthService.checkHealth(
                    baseURL: serverURL,
                    port: port,
                    useHTTP: useHTTP
                )
            }
            await send(.healthCheckResult(result))
        }
    }
}
