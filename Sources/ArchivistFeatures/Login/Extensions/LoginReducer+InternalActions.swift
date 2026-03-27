import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension LoginReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .loginCompleted:
            return handleLoginCompleted(state: &state)
        case .loginFailed(let error):
            return handleLoginFailed(error, state: &state)
        case .tokenReceived(let token):
            return handleTokenReceived(token, state: &state)
        case .tokenFailed(let error):
            return handleTokenFailed(error, state: &state)
        case .pingSucceeded:
            return handlePingSucceeded(state: &state)
        case .pingFailed:
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
            do {
                let response = try await userService.getToken(
                    baseURL: details.serverAddress,
                    port: Int(details.port),
                    useHTTP: details.useHTTP
                )
                if let token = response.token {
                    await send(.tokenReceived(token))
                } else {
                    await send(.tokenFailed(NetworkingError.missingData))
                }
            } catch {
                await send(.tokenFailed(error))
            }
        }
    }

    private func handleLoginFailed(_ error: Error, state: inout State) -> Effect<Action> {
        state.isLoading = false
        if let networkError = error as? NetworkingError {
            switch networkError {
            case .errorStatusCode(let code, _):
                let message = code == 403
                    ? String(localized: "Invalid username or password")
                    : String(localized: "Server error: \(code)")
                state.alert = AlertState {
                    TextState(String(localized: "Login Failed"))
                } message: {
                    TextState(message)
                }
            case .invalidURL:
                state.alert = AlertState {
                    TextState(String(localized: "Login Failed"))
                } message: {
                    TextState(String(localized: "Invalid server URL"))
                }
            case .missingData:
                state.alert = AlertState {
                    TextState(String(localized: "Login Failed"))
                } message: {
                    TextState(String(localized: "No response from server"))
                }
            }
        } else {
            state.alert = AlertState {
                TextState(String(localized: "Could Not Connect"))
            } message: {
                TextState(String(localized: "Please check your server details and try again."))
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
            do {
                _ = try await pingService.ping(config: config)
                await send(.pingSucceeded)
            } catch {
                await send(.pingFailed(error))
            }
        }
    }

    private func handleTokenFailed(_ error: Error, state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.alert = AlertState {
            TextState(String(localized: "Login Failed"))
        } message: {
            TextState(String(localized: "Login succeeded but no API token was returned."))
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
            TextState(String(localized: "Could Not Connect"))
        } message: {
            TextState(String(localized: "Please check your server details and try again."))
        }
        state.pendingToken = nil
        return .none
    }
}
