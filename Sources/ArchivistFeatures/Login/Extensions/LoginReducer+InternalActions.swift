import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension LoginReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .loginResult(.success):
            return handleLoginCompleted(state: &state)
        case .loginResult(.failure(let error)):
            return handleLoginFailed(error, state: &state)
        case .tokenResult(.success(let token)):
            return handleTokenReceived(token, state: &state)
        case .tokenResult(.failure(let error)):
            return handleTokenFailed(error, state: &state)
        case .pingResult(.success):
            return handlePingSucceeded(state: &state)
        case .pingResult(.failure):
            return handlePingFailed(state: &state)
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleLoginCompleted(state: inout State) -> Effect<Action> {
        let details = state.registrationDetails
        let userService = self.userService
        return .run { send in
            let result = await Result {
                let response = try await userService.getToken(
                    baseURL: details.serverAddress,
                    port: Int(details.port),
                    useHTTP: details.useHTTP
                )
                guard let token = response.token else {
                    throw NetworkingError.missingData
                }
                return token
            }
            await send(.tokenResult(result))
        }
    }

    private func handleLoginFailed(_ error: Error, state: inout State) -> Effect<Action> {
        state.isLoading = false
        if let networkError = error as? NetworkingError {
            switch networkError {
            case .errorStatusCode(let code, _):
                let message = code == 403
                    ? String.localised("login.invalidCredentials", table: .login)
                    : String.localised("Server error: \(code)", table: .login)
                state.alert = AlertState {
                    TextState(String.localised("login.loginFailed", table: .login))
                } message: {
                    TextState(message)
                }
            case .invalidURL:
                state.alert = AlertState {
                    TextState(String.localised("login.loginFailed", table: .login))
                } message: {
                    TextState(String.localised("login.invalidServerUrl", table: .login))
                }
            case .missingData:
                state.alert = AlertState {
                    TextState(String.localised("login.loginFailed", table: .login))
                } message: {
                    TextState(String.localised("login.noResponse", table: .login))
                }
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

    private func handleTokenReceived(_ token: String, state: inout State) -> Effect<Action> {
        let details = state.registrationDetails
        let config = ServerConfig(
            baseURL: details.serverAddress,
            port: Int(details.port),
            apiToken: token,
            useHTTP: details.useHTTP
        )
        state.pendingToken = token
        let pingService = self.pingService
        return .run { send in
            let result = await Result {
                _ = try await pingService.ping(config: config)
            }
            await send(.pingResult(result))
        }
    }

    private func handleTokenFailed(_ error: Error, state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.alert = AlertState {
            TextState(String.localised("login.loginFailed", table: .login))
        } message: {
            TextState(String.localised("login.noToken", table: .login))
        }
        return .none
    }

    private func handlePingSucceeded(state: inout State) -> Effect<Action> {
        state.isLoading = false
        guard let token = state.pendingToken else { return .none }
        return .send(.loginSucceeded(token, username: state.username, password: state.password))
    }

    private func handlePingFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.alert = AlertState {
            TextState(String.localised("login.couldNotConnect", table: .login))
        } message: {
            TextState(String.localised("login.checkDetails", table: .login))
        }
        state.pendingToken = nil
        return .none
    }
}
