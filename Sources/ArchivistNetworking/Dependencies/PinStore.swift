import Dependencies
import DependenciesMacros
import Foundation
import KeychainAccess

/// Stores the child-mode PIN in the Keychain.
///
/// The PIN used to live in `UserDefaults.standard` via
/// `@Shared(.appStorage(ChildMode.pinKey))`. The live store migrates it on
/// the first `load()` that finds the Keychain empty: the old value is copied
/// into the Keychain and removed from `UserDefaults`.
@DependencyClient
public struct PinStore: Sendable {
    /// The stored PIN, or `nil` when none is set. An empty PIN counts as none.
    public var load: @Sendable () -> String? = { nil }
    public var save: @Sendable (_ pin: String) throws -> Void
    public var clear: @Sendable () throws -> Void
}

extension PinStore: DependencyKey {
    /// Keychain service shared with `KeychainService`.
    static let keychainService = "com.mintywater.archivist"
    static let keychainAccount = "childModePin"
    /// `ChildMode.pinKey` — the pre-Keychain `UserDefaults.standard` key.
    /// Duplicated because `ChildMode` lives in `ArchivistComponents`.
    static let legacyDefaultsKey = "childModePin"

    public static var liveValue: PinStore {
        let service = keychainService
        let account = keychainAccount
        let legacyKey = legacyDefaultsKey
        return PinStore(
            load: {
                let keychain = Keychain(service: service)
                if let stored = try? keychain.get(account), !stored.isEmpty {
                    return stored
                }
                // One-time migration from UserDefaults.
                let defaults = UserDefaults.standard
                guard let legacy = defaults.string(forKey: legacyKey), !legacy.isEmpty else {
                    return nil
                }
                do {
                    try keychain.set(legacy, key: account)
                    defaults.removeObject(forKey: legacyKey)
                } catch {
                    // Leave the legacy value in place so the next load retries.
                    reportIssue(error)
                }
                return legacy
            },
            save: { pin in
                do {
                    try Keychain(service: service).set(pin, key: account)
                } catch {
                    throw KeychainError.saveFailed((error as? Status)?.rawValue ?? errSecParam)
                }
                UserDefaults.standard.removeObject(forKey: legacyKey)
            },
            clear: {
                do {
                    try Keychain(service: service).remove(account)
                } catch {
                    throw KeychainError.deleteFailed((error as? Status)?.rawValue ?? errSecParam)
                }
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
        )
    }

    /// Unimplemented: every endpoint reports an issue. Use `.inMemory()`.
    public static var testValue: PinStore { PinStore() }

    public static var previewValue: PinStore { .inMemory() }

    /// A store backed by memory, optionally seeded with a PIN.
    public static func inMemory(_ pin: String? = nil) -> PinStore {
        let storage = LockIsolated(pin)
        return PinStore(
            load: {
                guard let value = storage.value, !value.isEmpty else { return nil }
                return value
            },
            save: { pin in storage.setValue(pin) },
            clear: { storage.setValue(nil) }
        )
    }
}

extension DependencyValues {
    /// The child-mode PIN, stored in the Keychain.
    public var pinStore: PinStore {
        get { self[PinStore.self] }
        set { self[PinStore.self] = newValue }
    }
}
