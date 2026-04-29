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

    /// Default value for the `vlcPrebufferToDisk` app-storage flag. tvOS ships
    /// with caching on because Apple TV streams have been pausing regularly
    /// without a parallel disk copy to fall back to.
    #if os(tvOS)
    public nonisolated static let defaultPrebufferEnabled: Bool = true
    #else
    public nonisolated static let defaultPrebufferEnabled: Bool = false
    #endif

    /// Default value for the `prebufferWifiOnly` app-storage flag. On tvOS
    /// there's no cellular to protect against, and a Wi-Fi-only gate would
    /// block prebuffer when the box is wired to ethernet, so tvOS ships with
    /// the gate off.
    #if os(tvOS)
    public nonisolated static let defaultPrebufferWifiOnly: Bool = false
    #else
    public nonisolated static let defaultPrebufferWifiOnly: Bool = true
    #endif

    /// Default value for the `useVLCPlayer` app-storage flag. VLC is now the
    /// default on every platform — it handles the end-of-media event reliably,
    /// has better streaming resilience (`:http-reconnect`), and works with the
    /// existing prebuffer cache. AVPlayer stays available as an opt-in.
    public nonisolated static let defaultUseVLCPlayer: Bool = true

    /// Default upper bound on the playback cache (5 GB). Stored as bytes in
    /// the `playbackCacheSizeLimitBytes` app-storage key. A value of `0`
    /// means unlimited.
    public nonisolated static let defaultCacheSizeLimitBytes: Int = 5_000_000_000

    /// Sentinel meaning "no upper bound" for the cache size limit.
    public nonisolated static let unlimitedCacheSizeBytes: Int = 0

    /// Sensible presets surfaced in Settings. Values are in bytes;
    /// `unlimitedCacheSizeBytes` (0) at the end represents "Unlimited".
    public nonisolated static let cacheSizeLimitPresetsBytes: [Int] = [
        1_000_000_000,
        2_000_000_000,
        5_000_000_000,
        10_000_000_000,
        20_000_000_000,
        unlimitedCacheSizeBytes,
    ]

    /// True when caching `expectedSize` bytes on top of what's already on
    /// disk would exceed `limitBytes`. `expectedSize == nil` falls back to
    /// "are we already over the limit" — best-effort when the caller
    /// doesn't know the file size up front.
    public func wouldExceedLimit(
        expectedSize: Int64?,
        limitBytes: Int
    ) -> Bool {
        guard limitBytes > 0 else { return false }
        let current = totalSize()
        let projected = current + Int64(expectedSize ?? 0)
        return projected > Int64(limitBytes)
    }

    /// Evict least-recently-used entries until `expectedSize` bytes can be
    /// added without exceeding `limitBytes`. `protecting` is skipped during
    /// eviction (the caller's own videoId — defensive, shouldn't normally
    /// be in cache yet at this point). Returns `true` if enough space was
    /// freed (or none was needed), `false` if even removing every evictable
    /// entry leaves the projected size over the limit.
    @discardableResult
    public func evictToFit(
        expectedSize: Int64?,
        limitBytes: Int,
        protecting videoId: String? = nil
    ) -> Bool {
        guard limitBytes > 0 else { return true }
        let limit = Int64(limitBytes)
        let needed = Int64(expectedSize ?? 0)
        var current = totalSize()
        if current + needed <= limit { return true }

        // entries() is most-recent-first, so reverse for LRU eviction.
        let candidates = entries()
            .reversed()
            .filter { $0.videoId != videoId }
        for entry in candidates {
            remove(videoId: entry.videoId)
            current -= entry.size
            if current + needed <= limit { return true }
        }
        return current + needed <= limit
    }

    /// Pure filesystem check that can be called from any actor context.
    /// Matches `cachedFileURL(for:)` but without the mtime touch so it's safe
    /// to call from reducer handlers / sync nonisolated code.
    public nonisolated static func isCached(videoId: String) -> Bool {
        let url = fileURL(for: videoId)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64, size > 0 {
            return true
        }
        return false
    }

    public struct Entry: Equatable, Sendable {
        public let videoId: String
        public let fileURL: URL
        public let size: Int64
        public let lastAccessed: Date
    }

    private var activeSessions: [String: URLSession] = [:]

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
        expectedSize: Int64?,
        limitBytes: Int,
        onCompleted: @escaping @MainActor (URL) -> Void
    ) {
        guard !videoId.isEmpty else { return }
        guard activeSessions[videoId] == nil else { return }
        if cachedFileURL(for: videoId) != nil {
            print("[PlaybackCache] Already cached: \(videoId)")
            onCompleted(Self.fileURL(for: videoId))
            return
        }
        if wouldExceedLimit(expectedSize: expectedSize, limitBytes: limitBytes) {
            let fitted = evictToFit(
                expectedSize: expectedSize,
                limitBytes: limitBytes,
                protecting: videoId
            )
            guard fitted else {
                print(
                    "[PlaybackCache] Skipping \(videoId): "
                        + "won't fit under cache limit even after eviction "
                        + "(\(limitBytes) bytes, currently \(totalSize()) bytes, "
                        + "needs \(expectedSize ?? 0) more)"
                )
                return
            }
            print(
                "[PlaybackCache] Evicted older entries to fit \(videoId) "
                    + "(now \(totalSize()) bytes used)"
            )
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

        print("[PlaybackCache] Starting download: \(videoId)")

        let delegate = DownloadProgressDelegate(
            videoId: videoId,
            destination: destination,
            onCompleted: { [weak self] in
                self?.activeSessions[videoId] = nil
                onCompleted(destination)
            },
            onFailed: { [weak self] in
                self?.activeSessions[videoId] = nil
            }
        )

        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        let downloadTask = session.downloadTask(with: request)
        activeSessions[videoId] = session
        delegate.session = session
        downloadTask.resume()
    }

    public func cancelDownload(videoId: String) {
        guard let session = activeSessions.removeValue(forKey: videoId) else { return }
        session.invalidateAndCancel()
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

    public nonisolated static func cacheDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PlaybackCache", isDirectory: true)
    }

    nonisolated static func fileURL(for videoId: String) -> URL {
        cacheDirectory().appendingPathComponent("\(videoId).mp4")
    }
}

// MARK: - Download Progress Delegate

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let videoId: String
    let destination: URL
    let onCompleted: @MainActor () -> Void
    let onFailed: @MainActor () -> Void
    var session: URLSession?
    private var lastLoggedPercent: Int = -1

    init(
        videoId: String,
        destination: URL,
        onCompleted: @escaping @MainActor () -> Void,
        onFailed: @escaping @MainActor () -> Void
    ) {
        self.videoId = videoId
        self.destination = destination
        self.onCompleted = onCompleted
        self.onFailed = onFailed
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let percent = Int(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100)
        // Log every 10%
        let bucket = percent / 10 * 10
        if bucket > lastLoggedPercent {
            lastLoggedPercent = bucket
            let megabytes = Double(totalBytesWritten) / 1_000_000
            let totalMegabytes = Double(totalBytesExpectedToWrite) / 1_000_000
            let current = String(format: "%.1f", megabytes)
            let total = String(format: "%.1f", totalMegabytes)
            print("[PlaybackCache] \(videoId): \(percent)% (\(current)/\(total) MB)")
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let http = downloadTask.response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let code = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? -1
            print("[PlaybackCache] \(videoId): failed with status \(code)")
            try? FileManager.default.removeItem(at: location)
            session.finishTasksAndInvalidate()
            Task { @MainActor in onFailed() }
            return
        }

        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            print("[PlaybackCache] \(videoId): complete")
            session.finishTasksAndInvalidate()
            Task { @MainActor in onCompleted() }
        } catch {
            print("[PlaybackCache] \(videoId): move failed - \(error.localizedDescription)")
            session.finishTasksAndInvalidate()
            Task { @MainActor in onFailed() }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }
        print("[PlaybackCache] \(videoId): error - \(error.localizedDescription)")
        session.finishTasksAndInvalidate()
        Task { @MainActor in onFailed() }
    }
}
#endif
