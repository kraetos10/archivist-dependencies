import ArchivistComponents
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

    /// The user confirmed, from the alert, that their server runs with
    /// `DISABLE_STATIC_AUTH=true`.
    func handleStaticAuthDisabledConfirmed(state: inout State) -> Effect<Action> {
        state.hasConfirmedStaticAuthDisabled = true
        return login(state: &state)
    }

    // MARK: - Private Handlers

    private func handleLoginButtonTapped(state: inout State) -> Effect<Action> {
        // The button stays focusable (and the field submittable) while a
        // login is in flight, so ignore repeats here.
        guard !state.isLoading else { return .none }
        guard state.hasConfirmedStaticAuthDisabled else {
            state.alert = .confirmStaticAuthDisabled
            return .none
        }
        return login(state: &state)
    }

    private func login(state: inout State) -> Effect<Action> {
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

extension AlertState where Action == LoginReducer.AlertAction {
    static var confirmStaticAuthDisabled: Self {
        AlertState {
            TextState(String.localised("login.staticAuth.confirmTitle", table: .login))
        } actions: {
            ButtonState(action: .staticAuthDisabledConfirmed) {
                TextState(String.localised("login.staticAuth.confirmAction", table: .login))
            }
            ButtonState(role: .cancel) {
                TextState(String.localised("login.staticAuth.notYet", table: .login))
            }
        } message: {
            TextState(String.localised("login.staticAuth.confirmMessage", table: .login))
        }
    }
}
