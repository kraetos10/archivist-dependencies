import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension LoginReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .loginButtonTapped:
            return handleLoginButtonTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleLoginButtonTapped(state: inout State) -> Effect<Action> {
        let token = state.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return .none }
        state.apiToken = token
        state.isLoading = true
        let config = ServerConfig(
            baseURL: state.registrationDetails.serverAddress,
            port: Int(state.registrationDetails.port),
            apiToken: token,
            useHTTP: state.registrationDetails.useHTTP
        )
        let pingService = self.pingService
        return .run { send in
            let result = await Result {
                _ = try await pingService.ping(config: config)
            }
            await send(.pingResult(result))
        }
    }
}
