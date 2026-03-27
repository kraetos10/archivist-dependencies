import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension ServerSetupReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .nextButtonTapped:
            LocalNetworkPrompt.triggerLocalNetworkPrivacyAlert()
            return handleNextButtonTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleNextButtonTapped(state: inout State) -> Effect<Action> {
        guard !state.registrationDetails.serverAddress.isEmpty else {
            return .none
        }
        state.isLoading = true
        let serverURL = state.registrationDetails.serverAddress
        let port = Int(state.registrationDetails.port)
        let useHTTP = state.registrationDetails.useHTTP
        let healthService = self.healthService
        return .run { send in
            do {
                try await healthService.checkHealth(
                    baseURL: serverURL,
                    port: port,
                    useHTTP: useHTTP
                )
                await send(.healthCheckSucceeded)
            } catch {
                await send(.healthCheckFailed(error))
            }
        }
    }
}
