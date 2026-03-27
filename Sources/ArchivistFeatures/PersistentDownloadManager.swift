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

    public init(videoId: String, title: String, progress: Double) {
        self.videoId = videoId
        self.title = title
        self.progress = progress
    }
}

public nonisolated protocol PersistentDownloadManagerType: Sendable {
    func startDownload(url: URL, videoId: String, title: String, authHeaders: [String: String]) async
    func isDownloading(videoId: String) async -> Bool
    func progress(for videoId: String) async -> Double
    func observe(videoId: String) async -> AsyncStream<DownloadEvent>
    func activeDownloads() async -> [DeviceDownloadInfo]
}

public final actor PersistentDownloadManager: PersistentDownloadManagerType {
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var currentProgress: [String: Double] = [:]
    private var titles: [String: String] = [:]
    private var observers: [String: [UUID: AsyncStream<DownloadEvent>.Continuation]] = [:]

    public init() {}

    public func startDownload(url: URL, videoId: String, title: String, authHeaders: [String: String]) {
        guard activeTasks[videoId] == nil else { return }
        currentProgress[videoId] = 0
        titles[videoId] = title

        let task = Task { [weak self] in
            guard let self else { return }
            @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
            let manager = VideoDownloadManager()
            nonisolated(unsafe) var lastWrittenProgress: Double = 0
            do {
                _ = try await manager.download(
                    url: url,
                    videoId: videoId,
                    authHeaders: authHeaders,
                    onProgress: { progress in
                        Task {
                            await self.updateProgress(videoId: videoId, value: progress)
                            if progress - lastWrittenProgress >= 0.05 {
                                try? deviceDownloadDatabase.updateProgress(videoId, progress)
                                lastWrittenProgress = progress
                            }
                        }
                    }
                )
                try? deviceDownloadDatabase.markCompleted(videoId, nil)
                await self.broadcast(videoId: videoId, event: .completed)
            } catch {
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

    private func updateProgress(videoId: String, value: Double) {
        currentProgress[videoId] = value
        broadcast(videoId: videoId, event: .progress(value))
    }

    private func broadcast(videoId: String, event: DownloadEvent) {
        guard let videoObservers = observers[videoId] else { return }
        for (_, continuation) in videoObservers {
            continuation.yield(event)
        }
    }

    private func cleanUp(videoId: String) {
        activeTasks[videoId] = nil
        currentProgress[videoId] = nil
        titles[videoId] = nil
        if let videoObservers = observers[videoId] {
            for (_, continuation) in videoObservers {
                continuation.finish()
            }
        }
        observers[videoId] = nil
    }

    private func removeObserver(videoId: String, id: UUID) {
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
