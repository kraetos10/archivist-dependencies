import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension LoginReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .loginButtonTapped:
            return handleLoginButtonTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleLoginButtonTapped(state: inout State) -> Effect<Action> {
        guard !state.username.isEmpty, !state.password.isEmpty else { return .none }
        state.isLoading = true
        let serverURL = state.registrationDetails.serverAddress
        let port = Int(state.registrationDetails.port)
        let useHTTP = state.registrationDetails.useHTTP
        let username = state.username
        let password = state.password
        let userService = self.userService
        return .run { send in
            let result = await Result {
                try await userService.login(
                    baseURL: serverURL,
                    port: port,
                    useHTTP: useHTTP,
                    username: username,
                    password: password
                )
            }
            await send(.loginResult(result))
        }
    }
}
