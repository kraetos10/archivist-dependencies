import Dependencies
import Foundation
import KeychainAccess

public protocol KeychainServiceType: Sendable {
    func save(token: String) throws
    func loadToken() -> String?
    func deleteToken() throws
}

public nonisolated enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}

public struct KeychainService: KeychainServiceType {
    private static let service = "com.mintywater.archivist"
    private static let accountToken = "apiToken"
    private static let legacyAccountUsername = "username"
    private static let legacyAccountPassword = "password"

    private var keychain: Keychain { Keychain(service: Self.service) }

    public init() {
        // Best-effort cleanup of legacy credential entries from the previous
        // username/password auth flow.
        try? keychain.remove(Self.legacyAccountUsername)
        try? keychain.remove(Self.legacyAccountPassword)
    }

    public func save(token: String) throws {
        do {
            try keychain.set(token, key: Self.accountToken)
        } catch {
            throw KeychainError.saveFailed((error as? Status)?.rawValue ?? errSecParam)
        }
    }

    public func loadToken() -> String? {
        try? keychain.get(Self.accountToken)
    }

    public func deleteToken() throws {
        do {
            try keychain.remove(Self.accountToken)
        } catch {
            throw KeychainError.deleteFailed((error as? Status)?.rawValue ?? errSecParam)
        }
    }
}
