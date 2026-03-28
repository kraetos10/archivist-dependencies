#if !os(watchOS)
import Foundation

/// On-disk cache for played videos so seeks become instant on subsequent plays
/// (and, once a parallel download finishes, instant mid-playback via a
/// backend `swapToLocalFile` call).
///
/// Lives in `Library/Caches/PlaybackCache/` — OS-managed cache location that
/// survives app launches but is fair game for the OS to purge under pressure.
/// We also sweep entries older than `expirationTTL` at app launch.
///
/// Concurrency: all public API is `@MainActor`. Background download work
/// runs inside a detached `Task`; only `onCompleted` callbacks bounce back
/// to the main actor.
@MainActor
public final class PlaybackCache {
    public static let shared = PlaybackCache()

    /// Files older than this (measured by last-access `contentModificationDate`)
    /// are swept at app launch. One day by default — long enough for "watch the
    /// same video again later today", short enough that disk doesn't grow.
    public nonisolated static let expirationTTL: TimeInterval = 60 * 60 * 24

    public struct Entry: Equatable, Sendable {
        public let videoId: String
        public let fileURL: URL
        public let size: Int64
        public let lastAccessed: Date
    }

    private var activeDownloads: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Lookup

    /// Returns the local file URL for a cached, non-empty video, or nil.
    /// Touches the mtime so LRU sweeping keeps recently-played entries alive.
    public func cachedFileURL(for videoId: String) -> URL? {
        let url = Self.fileURL(for: videoId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs?[.size] as? Int64, size > 0 {
            touch(videoId: videoId)
            return url
        }
        return nil
    }

    /// Updates the file's modification date to "now", marking it as recently used.
    public func touch(videoId: String) {
        let url = Self.fileURL(for: videoId)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
    }

    // MARK: - Download

    /// Kicks off a background download of `url` into the cache, if one is not
    /// already in progress and the file is not already cached. `authHeaders`
    /// are applied once to the request; nginx validates a signed-URL sig at
    /// response start so in-flight downloads survive later token rotation.
    /// Calls `onCompleted` on the main actor when the file is fully written.
    public func startDownload(
        url: URL,
        videoId: String,
        authHeaders: [String: String],
        onCompleted: @escaping @MainActor (URL) -> Void
    ) {
        guard !videoId.isEmpty else { return }
        guard activeDownloads[videoId] == nil else { return }
        if cachedFileURL(for: videoId) != nil {
            onCompleted(Self.fileURL(for: videoId))
            return
        }

        let destination = Self.fileURL(for: videoId)
        try? FileManager.default.createDirectory(
            at: Self.cacheDirectory(),
            withIntermediateDirectories: true
        )

        var request = URLRequest(url: url)
        for (header, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let task = Task { [weak self] in
            let session = URLSession(configuration: .default)
            defer { session.finishTasksAndInvalidate() }

            do {
                let (tempURL, response) = try await session.download(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    try? FileManager.default.removeItem(at: tempURL)
                    return
                }
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: tempURL, to: destination)
                await MainActor.run {
                    self?.activeDownloads[videoId] = nil
                    onCompleted(destination)
                }
            } catch {
                await MainActor.run {
                    self?.activeDownloads[videoId] = nil
                }
            }
        }
        activeDownloads[videoId] = task
    }

    public func cancelDownload(videoId: String) {
        activeDownloads[videoId]?.cancel()
        activeDownloads[videoId] = nil
    }

    // MARK: - Cache management

    /// Sum of all files in the cache directory, in bytes.
    public func totalSize() -> Int64 {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: Self.cacheDirectory(),
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return contents.reduce(into: Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
    }

    /// All cached entries sorted by most-recently-used first.
    public func entries() -> [Entry] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: Self.cacheDirectory(),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "mp4" }
            .compactMap { url -> Entry? in
                let values = try? url.resourceValues(forKeys: [
                    .fileSizeKey, .contentModificationDateKey
                ])
                let size = Int64(values?.fileSize ?? 0)
                let date = values?.contentModificationDate ?? .distantPast
                let videoId = url.deletingPathExtension().lastPathComponent
                return Entry(
                    videoId: videoId,
                    fileURL: url,
                    size: size,
                    lastAccessed: date
                )
            }
            .sorted { $0.lastAccessed > $1.lastAccessed }
    }

    /// Remove a single cached file by video id.
    public func remove(videoId: String) {
        let url = Self.fileURL(for: videoId)
        try? FileManager.default.removeItem(at: url)
    }

    /// Remove every cached file.
    public func clearAll() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: Self.cacheDirectory(),
            includingPropertiesForKeys: nil
        ) else { return }
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Remove files whose modification date is older than `ttl` ago. Call once
    /// at launch. Cheap enough to run synchronously.
    public func sweepExpired(ttl: TimeInterval = PlaybackCache.expirationTTL) {
        let cutoff = Date().addingTimeInterval(-ttl)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: Self.cacheDirectory(),
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let date = values?.contentModificationDate, date < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Paths

    public static func cacheDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PlaybackCache", isDirectory: true)
    }

    static func fileURL(for videoId: String) -> URL {
        cacheDirectory().appendingPathComponent("\(videoId).mp4")
    }
}
#endif
