import Dependencies
import DependenciesMacros
import Foundation
import KeychainAccess

public nonisolated enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}

@DependencyClient
public struct KeychainService: Sendable {
    public var save: @Sendable (_ token: String) throws -> Void
    public var loadToken: @Sendable () -> String? = { nil }
    public var deleteToken: @Sendable () throws -> Void
}

extension KeychainService: DependencyKey {
    public static let liveValue: KeychainService = {
        let service = "com.mintywater.archivist"
        let accountToken = "apiToken"

        // Best-effort cleanup of legacy credential entries from the previous
        // username/password auth flow.
        let legacy = Keychain(service: service)
        try? legacy.remove("username")
        try? legacy.remove("password")

        return KeychainService(
            save: { token in
                do {
                    try Keychain(service: service).set(token, key: accountToken)
                } catch {
                    throw KeychainError.saveFailed((error as? Status)?.rawValue ?? errSecParam)
                }
            },
            loadToken: {
                try? Keychain(service: service).get(accountToken)
            },
            deleteToken: {
                do {
                    try Keychain(service: service).remove(accountToken)
                } catch {
                    throw KeychainError.deleteFailed((error as? Status)?.rawValue ?? errSecParam)
                }
            }
        )
    }()

    public static var testValue: KeychainService { KeychainService() }
}
