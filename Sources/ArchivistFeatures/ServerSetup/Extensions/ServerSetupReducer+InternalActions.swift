import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

extension ServerSetupReducer {
    func handleHealthCheckResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoading = false
        switch result {
        case .success:
            state.path.append(.login(LoginReducer.State(
                registrationDetails: state.registrationDetails
            )))
        case .failure:
            state.alert = .couldNotConnect
        }
        return .none
    }

    func handleChildPinConfirmed(
        _ pin: String,
        state: inout State
    ) -> Effect<Action> {
        state.pinSetup = nil
        return .run { [pinStore] send in
            await send(.childModeSaveResult(Result {
                try pinStore.save(pin)
                return true
            }))
        }
    }

    /// Child mode only changes once the Keychain write it depends on has
    /// landed; a failure puts the switch back and says why.
    func handleChildModeSaveResult(
        _ result: Result<Bool, Error>,
        state: inout State
    ) -> Effect<Action> {
        switch result {
        case .success(let enabled):
            state.$childModeEnabled.withLock { $0 = enabled }
            state.childModeToggle = enabled
        case .failure:
            state.childModeToggle = state.childModeEnabled
            state.alert = .childModeSaveFailed
        }
        return .none
    }

    func handleLoginSucceeded(
        token: String,
        state: inout State
    ) -> Effect<Action> {
        let details = state.registrationDetails
        let config = ServerConfig(
            baseURL: details.serverAddress,
            port: Int(details.port),
            apiToken: token,
            useHTTP: details.useHTTP
        )
        return .run { [database, keychainService] send in
            do {
                try await database.write { db in
                    try ServerConnection
                        .insert {
                            ServerConnection(
                                serverAddress: details.serverAddress,
                                port: details.port,
                                useHTTP: details.useHTTP
                            )
                        } onConflict: {
                            $0.id
                        } doUpdate: { conn, excluded in
                            conn.serverAddress = excluded.serverAddress
                            conn.port = excluded.port
                            conn.useHTTP = excluded.useHTTP
                        }
                        .execute(db)
                }
                try keychainService.save(token: token)
                await send(.loginCompleted(config))
            } catch {
                await send(.loginSaveFailed)
            }
        }
    }
}

extension AlertState where Action == ServerSetupReducer.AlertAction {
    static var couldNotConnect: Self {
        AlertState {
            TextState(String.localised("login.couldNotConnect", table: .login))
        } message: {
            TextState(String.localised("login.checkDetails", table: .login))
        }
    }

    static var loginSaveFailed: Self {
        AlertState {
            TextState(String.localised("login.saveFailed.title", table: .login))
        } message: {
            TextState(String.localised("login.saveFailed.message", table: .login))
        }
    }

    static var childModeSaveFailed: Self {
        AlertState {
            TextState(String.localised("childMode.saveFailed.title", table: .login))
        } message: {
            TextState(String.localised("childMode.saveFailed.message", table: .login))
        }
    }
}
