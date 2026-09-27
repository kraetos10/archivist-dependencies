import Dependencies
import DependenciesMacros
import Foundation

/// The server connection shared through the app group, read by CarPlay,
/// the Top Shelf extension and the watch bridge.
///
/// The app group suite is not known to this package: configure the live
/// store at launch, before anything resolves it —
///
/// ```swift
/// prepareDependencies {
///     $0.serverConfigStore = .live(suiteName: "group.…")
/// }
/// ```
///
/// Until configured, `liveValue` reports an issue on every call.
@DependencyClient
public struct ServerConfigStore: Sendable {
    public var load: @Sendable () -> ServerConfig? = { nil }
    public var save: @Sendable (_ config: ServerConfig) -> Void
    public var clear: @Sendable () -> Void
}

extension ServerConfigStore {
    /// Where the API token lives.
    public enum TokenStorage: Sendable {
        /// The shared blob is token-stripped; `load()` merges the token back
        /// from `KeychainService` and returns `nil` without one. The iOS app,
        /// CarPlay and the watch bridge on the phone.
        case keychain
        /// The token is stored in the blob as-is. The watch, which has no
        /// shared Keychain and receives the full config over WatchConnectivity.
        case inline
    }

    /// The `UserDefaults` key the blob is stored under.
    public static let defaultKey = "serverConfig"

    /// A store backed by the app group's `UserDefaults` suite.
    public static func live(
        suiteName: String,
        key: String = ServerConfigStore.defaultKey,
        tokenStorage: TokenStorage = .keychain
    ) -> ServerConfigStore {
        @Sendable func defaults() -> UserDefaults? {
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                reportIssue("No UserDefaults suite named '\(suiteName)'. Check the app group entitlement.")
                return nil
            }
            return defaults
        }

        return ServerConfigStore(
            load: {
                guard let data = defaults()?.data(forKey: key),
                      let stored = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
                    return nil
                }
                switch tokenStorage {
                case .inline:
                    return stored
                case .keychain:
                    @Dependency(\.keychainService) var keychain
                    guard let token = keychain.loadToken(), !token.isEmpty else { return nil }
                    return stored.withAPIToken(token)
                }
            },
            save: { config in
                let stored = tokenStorage == .keychain ? config.withAPIToken("") : config
                do {
                    let data = try JSONEncoder().encode(stored)
                    defaults()?.set(data, forKey: key)
                } catch {
                    reportIssue(error)
                }
            },
            clear: {
                defaults()?.removeObject(forKey: key)
            }
        )
    }

    /// A store backed by memory, optionally seeded with a config.
    public static func inMemory(_ config: ServerConfig? = nil) -> ServerConfigStore {
        let storage = LockIsolated(config)
        return ServerConfigStore(
            load: { storage.value },
            save: { config in storage.setValue(config) },
            clear: { storage.setValue(nil) }
        )
    }
}

extension ServerConfigStore: DependencyKey {
    /// Unconfigured: reports an issue on every call. The app replaces it via
    /// `prepareDependencies` with `.live(suiteName:)`.
    public static var liveValue: ServerConfigStore {
        let message = """
            ServerConfigStore is not configured. At launch, call \
            'prepareDependencies { $0.serverConfigStore = .live(suiteName: …) }'.
            """
        return ServerConfigStore(
            load: {
                reportIssue(message)
                return nil
            },
            save: { _ in reportIssue(message) },
            clear: { reportIssue(message) }
        )
    }

    /// Unimplemented: every endpoint reports an issue. Use `.inMemory()`.
    public static var testValue: ServerConfigStore { ServerConfigStore() }

    public static var previewValue: ServerConfigStore { .inMemory() }
}

extension DependencyValues {
    /// The app-group shared server connection.
    public var serverConfigStore: ServerConfigStore {
        get { self[ServerConfigStore.self] }
        set { self[ServerConfigStore.self] = newValue }
    }
}

private extension ServerConfig {
    func withAPIToken(_ token: String) -> ServerConfig {
        ServerConfig(
            baseURL: baseURL,
            port: port,
            apiToken: token,
            useHTTP: useHTTP
        )
    }
}
