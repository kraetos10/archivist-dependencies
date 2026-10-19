import Dependencies
import DependenciesMacros
import Foundation
import KeychainAccess

/// Stores the user's own YouTube Data API key in the Keychain. Like the
/// child-mode PIN, it never goes through `UserDefaults`.
@DependencyClient
public struct YouTubeAPIKeyStore: Sendable {
    /// The stored key, or `nil` when none is set. An empty key counts as none.
    public var load: @Sendable () -> String? = { nil }
    public var save: @Sendable (_ key: String) throws -> Void
    public var clear: @Sendable () throws -> Void
}

extension YouTubeAPIKeyStore: DependencyKey {
    static let keychainService = "com.mintywater.archivist"
    static let keychainAccount = "youtubeAPIKey"

    public static var liveValue: YouTubeAPIKeyStore {
        let service = keychainService
        let account = keychainAccount
        return YouTubeAPIKeyStore(
            load: {
                guard let stored = try? Keychain(service: service).get(account),
                      !stored.isEmpty else { return nil }
                return stored
            },
            save: { key in
                do {
                    try Keychain(service: service).set(key, key: account)
                } catch {
                    throw KeychainError.saveFailed((error as? Status)?.rawValue ?? errSecParam)
                }
            },
            clear: {
                do {
                    try Keychain(service: service).remove(account)
                } catch {
                    throw KeychainError.deleteFailed((error as? Status)?.rawValue ?? errSecParam)
                }
            }
        )
    }

    /// Unimplemented: every endpoint reports an issue. Use `.inMemory()`.
    public static var testValue: YouTubeAPIKeyStore { YouTubeAPIKeyStore() }

    public static var previewValue: YouTubeAPIKeyStore { .inMemory() }

    /// A store backed by memory, optionally seeded with a key.
    public static func inMemory(_ key: String? = nil) -> YouTubeAPIKeyStore {
        let storage = LockIsolated(key)
        return YouTubeAPIKeyStore(
            load: {
                guard let value = storage.value, !value.isEmpty else { return nil }
                return value
            },
            save: { key in storage.setValue(key) },
            clear: { storage.setValue(nil) }
        )
    }
}

extension DependencyValues {
    public var youTubeAPIKeyStore: YouTubeAPIKeyStore {
        get { self[YouTubeAPIKeyStore.self] }
        set { self[YouTubeAPIKeyStore.self] = newValue }
    }
}
