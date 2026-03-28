import Dependencies
import Foundation
import KeychainAccess

public protocol KeychainServiceType: Sendable {
    func save(token: String) throws
    func loadToken() -> String?
    func deleteToken() throws
    func saveCredentials(
        username: String,
        password: String
    ) throws
    func loadCredentials() -> (username: String, password: String)?
    func deleteCredentials() throws
}

public nonisolated enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}

public struct KeychainService: KeychainServiceType {
    private static let service = "com.mintywater.archivist"
    private static let accountToken = "apiToken"
    private static let accountUsername = "username"
    private static let accountPassword = "password"

    private var keychain: Keychain { Keychain(service: Self.service) }

    public init() {}

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

    public func saveCredentials(
        username: String,
        password: String
    ) throws {
        do {
            try keychain.set(username, key: Self.accountUsername)
            try keychain.set(password, key: Self.accountPassword)
        } catch {
            throw KeychainError.saveFailed((error as? Status)?.rawValue ?? errSecParam)
        }
    }

    public func loadCredentials() -> (username: String, password: String)? {
        guard let username = try? keychain.get(Self.accountUsername),
              let password = try? keychain.get(Self.accountPassword) else {
            return nil
        }
        return (username, password)
    }

    public func deleteCredentials() throws {
        do {
            try keychain.remove(Self.accountUsername)
            try keychain.remove(Self.accountPassword)
        } catch {
            throw KeychainError.deleteFailed((error as? Status)?.rawValue ?? errSecParam)
        }
    }
}
