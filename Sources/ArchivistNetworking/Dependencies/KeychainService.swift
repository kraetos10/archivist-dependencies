import Dependencies
import Foundation
import Security

public protocol KeychainServiceType: Sendable {
    func save(token: String) throws
    func loadToken() -> String?
    func deleteToken() throws
    func saveCredentials(username: String, password: String) throws
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

    public init() {}

    public func save(token: String) throws {
        try saveItem(account: Self.accountToken, data: Data(token.utf8))
    }

    public func loadToken() -> String? {
        loadItem(account: Self.accountToken)
    }

    public func deleteToken() throws {
        try deleteItem(account: Self.accountToken)
    }

    public func saveCredentials(username: String, password: String) throws {
        try saveItem(account: Self.accountUsername, data: Data(username.utf8))
        try saveItem(account: Self.accountPassword, data: Data(password.utf8))
    }

    public func loadCredentials() -> (username: String, password: String)? {
        guard let username = loadItem(account: Self.accountUsername),
              let password = loadItem(account: Self.accountPassword) else {
            return nil
        }
        return (username, password)
    }

    public func deleteCredentials() throws {
        try deleteItem(account: Self.accountUsername)
        try deleteItem(account: Self.accountPassword)
    }

    // MARK: - Private

    private func saveItem(account: String, data: Data) throws {
        try? deleteItem(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func loadItem(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
