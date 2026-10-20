import CryptoKit
import Dependencies
import DependenciesMacros
import Foundation

/// A small on-disk cache for Discover's shelves.
///
/// A search costs 100 of the key's 10,000 daily units, so building the shelves
/// afresh on every visit would spend the allowance in a day. Entries are
/// keyed by the caller (which folds in the key's owner and the time bucket)
/// and live in the Caches directory, where the system may clear them.
@DependencyClient
public struct DiscoverCache: Sendable {
    public var load: @Sendable (_ name: String) -> Data? = { _ in nil }
    public var save: @Sendable (_ name: String, _ data: Data) -> Void
}

extension DiscoverCache: DependencyKey {
    public static var liveValue: DiscoverCache {
        let directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appending(path: "DiscoverShelves", directoryHint: .isDirectory)
        // The name is hashed so nothing from a key's owner reaches a file name.
        let file: @Sendable (String) -> URL? = { name in
            let digest = SHA256.hash(data: Data(name.utf8)).map { String(format: "%02x", $0) }.joined()
            return directory?.appending(path: "\(digest.prefix(32)).json")
        }
        return DiscoverCache(
            load: { name in
                guard let url = file(name) else { return nil }
                return try? Data(contentsOf: url)
            },
            save: { name, data in
                guard let directory, let url = file(name) else { return }
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            }
        )
    }

    /// Unimplemented: every endpoint reports an issue. Use `.inMemory()`.
    public static var testValue: DiscoverCache { DiscoverCache() }

    public static var previewValue: DiscoverCache { .inMemory() }

    public static func inMemory() -> DiscoverCache {
        let storage = LockIsolated<[String: Data]>([:])
        return DiscoverCache(
            load: { storage.value[$0] },
            save: { name, data in storage.withValue { $0[name] = data } }
        )
    }
}

extension DependencyValues {
    public var discoverCache: DiscoverCache {
        get { self[DiscoverCache.self] }
        set { self[DiscoverCache.self] = newValue }
    }
}
