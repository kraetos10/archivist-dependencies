import ArchivistNetworking
import Dependencies
import Foundation

public enum DownloadEvent: Sendable {
    case progress(Double)
    case completed
    case failed(String)
}

public nonisolated struct DeviceDownloadInfo: Equatable, Sendable, Identifiable {
    public let videoId: String
    public let title: String
    public let progress: Double

    public var id: String { videoId }

    public init(
        videoId: String,
        title: String,
        progress: Double
    ) {
        self.videoId = videoId
        self.title = title
        self.progress = progress
    }
}

public nonisolated protocol PersistentDownloadManagerType: Sendable {
    func startDownload(
        url: URL,
        videoId: String,
        title: String,
        expectedSize: Int64?,
        authHeaders: [String: String]
    ) async
    func isDownloading(videoId: String) async -> Bool
    func progress(for videoId: String) async -> Double
    func observe(videoId: String) async -> AsyncStream<DownloadEvent>
    func activeDownloads() async -> [DeviceDownloadInfo]
}

public final actor PersistentDownloadManager: PersistentDownloadManagerType {
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var currentProgress: [String: Double] = [:]
    private var lastWrittenProgress: [String: Double] = [:]
    private var titles: [String: String] = [:]
    private var observers: [String: [UUID: AsyncStream<DownloadEvent>.Continuation]] = [:]

    public init() {}

    public func startDownload(
        url: URL,
        videoId: String,
        title: String,
        expectedSize: Int64?,
        authHeaders: [String: String]
    ) {
        guard activeTasks[videoId] == nil else { return }
        currentProgress[videoId] = 0
        lastWrittenProgress[videoId] = 0
        titles[videoId] = title

        let task = Task { [weak self] in
            guard let self else { return }
            @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase

            let progress = Progress(totalUnitCount: 100)
            let manager = VideoDownloadManager(progress: progress)

            // Observe Progress via KVO on a background queue
            let observation = progress.observe(\.fractionCompleted) { progress, _ in
                let value = progress.fractionCompleted
                Task {
                    await self.handleProgress(
                        videoId: videoId,
                        value: value,
                        database: deviceDownloadDatabase
                    )
                }
            }

            do {
                let savedURL = try await manager.download(
                    url: url,
                    videoId: videoId,
                    expectedSize: expectedSize,
                    authHeaders: authHeaders,
                    onProgress: { _ in }
                )
                observation.invalidate()
                // Get the actual file size for storage tracking
                let fileSize = (try? FileManager.default.attributesOfItem(
                    atPath: savedURL.path
                )[.size] as? Int) ?? nil
                try? deviceDownloadDatabase.markCompleted(videoId, fileSize)
                await self.broadcast(videoId: videoId, event: .completed)
            } catch {
                observation.invalidate()
                try? deviceDownloadDatabase.markFailed(videoId)
                await self.broadcast(videoId: videoId, event: .failed(error.localizedDescription))
            }
            await self.cleanUp(videoId: videoId)
        }
        activeTasks[videoId] = task
    }

    public func isDownloading(videoId: String) -> Bool {
        activeTasks[videoId] != nil
    }

    public func progress(for videoId: String) -> Double {
        currentProgress[videoId] ?? 0
    }

    public func activeDownloads() -> [DeviceDownloadInfo] {
        activeTasks.keys.map { videoId in
            DeviceDownloadInfo(
                videoId: videoId,
                title: titles[videoId] ?? videoId,
                progress: currentProgress[videoId] ?? 0
            )
        }
        .sorted { $0.videoId < $1.videoId }
    }

    public func observe(videoId: String) -> AsyncStream<DownloadEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            self.observers[videoId, default: [:]][id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(videoId: videoId, id: id) }
            }
        }
    }

    // MARK: - Private

    private func handleProgress(
        videoId: String,
        value: Double,
        database: DeviceDownloadDatabase
    ) {
        guard value >= 0 else { return }
        currentProgress[videoId] = value
        broadcast(videoId: videoId, event: .progress(value))

        // Write to DB every 1% so the @FetchAll query picks up changes
        let lastWritten = lastWrittenProgress[videoId] ?? 0
        if value - lastWritten >= 0.01 {
            try? database.updateProgress(videoId, value)
            lastWrittenProgress[videoId] = value
        }
    }

    private func broadcast(
        videoId: String,
        event: DownloadEvent
    ) {
        guard let videoObservers = observers[videoId] else { return }
        for (_, continuation) in videoObservers {
            continuation.yield(event)
        }
    }

    private func cleanUp(videoId: String) {
        activeTasks[videoId] = nil
        currentProgress[videoId] = nil
        lastWrittenProgress[videoId] = nil
        titles[videoId] = nil
        if let videoObservers = observers[videoId] {
            for (_, continuation) in videoObservers {
                continuation.finish()
            }
        }
        observers[videoId] = nil
    }

    private func removeObserver(
        videoId: String,
        id: UUID
    ) {
        observers[videoId]?[id] = nil
    }
}

// MARK: - Dependency Registration

extension PersistentDownloadManager: DependencyKey {
    public static let liveValue: PersistentDownloadManagerType = PersistentDownloadManager()
    public static let testValue: PersistentDownloadManagerType = PersistentDownloadManager()
}

extension DependencyValues {
    public var persistentDownloadManager: PersistentDownloadManagerType {
        get { self[PersistentDownloadManager.self] }
        set { self[PersistentDownloadManager.self] = newValue }
    }
}
