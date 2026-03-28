#if os(watchOS)
import ArchivistNetworking
import Foundation

public struct WatchDownloadItem: Sendable {
    public let videoId: String
    public let title: String
    public let channelName: String
    public let mediaUrl: String?
    public let duration: Int?
    public let durationStr: String?
    public let thumbPath: String?

    public init(
        videoId: String,
        title: String,
        channelName: String,
        mediaUrl: String?,
        duration: Int?,
        durationStr: String?,
        thumbPath: String?
    ) {
        self.videoId = videoId
        self.title = title
        self.channelName = channelName
        self.mediaUrl = mediaUrl
        self.duration = duration
        self.durationStr = durationStr
        self.thumbPath = thumbPath
    }
}

public enum WatchDownloadError: Error {
    case alreadyDownloading
    case noMediaURL
    case exportFailed
    case downloadFailed
}

@MainActor
@Observable
public final class WatchDownloadManager {
    public static let shared = WatchDownloadManager()

    public var progress: Double = 0
    public var isDownloading: Bool = false
    public var activeDownloadTitle: String?
    public var activeDownloadChannel: String?

    private let storage = WatchAudioStorage()
    private let sessionDelegate: DownloadSessionDelegate

    private var activeItem: WatchDownloadItem?

    public init() {
        let delegate = DownloadSessionDelegate()
        self.sessionDelegate = delegate
    }

    public func reconnectBackgroundSession() {
        _ = sessionDelegate.backgroundSession
    }

    public func handleBackgroundSessionCompletion(_ handler: @escaping @Sendable () -> Void) {
        sessionDelegate.backgroundCompletionHandler = handler
    }

    public func downloadAudio(
        video: WatchDownloadItem,
        config: ServerConfig
    ) async throws {
        guard !isDownloading else {
            throw WatchDownloadError.alreadyDownloading
        }
        guard let mediaPath = video.mediaUrl,
              let mediaURL = config.fullURL(for: mediaPath) else {
            throw WatchDownloadError.noMediaURL
        }

        activeItem = video
        isDownloading = true
        progress = 0
        activeDownloadTitle = video.title
        activeDownloadChannel = video.channelName

        storage.ensureDirectoryExists()

        var request = URLRequest(url: mediaURL)
        for (key, value) in config.authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let delegate = sessionDelegate
        let storageRef = storage

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                delegate.configure(
                    continuation: cont,
                    item: video,
                    storage: storageRef,
                    onProgress: { [weak self] fraction in
                        Task { @MainActor in
                            self?.progress = fraction
                        }
                    },
                    onComplete: { [weak self] record in
                        Task { @MainActor in
                            if let record {
                                WatchDownloadCatalog.shared.add(record)
                            }
                            self?.clearState()
                        }
                    }
                )
                delegate.backgroundSession.downloadTask(with: request).resume()
            }
        } catch {
            clearState()
            throw error
        }
    }

    public func cancelDownload() {
        sessionDelegate.backgroundSession.invalidateAndCancel()
        sessionDelegate.resetSession()
        clearState()
    }

    public func deleteDownload(videoId: String) throws {
        try storage.deleteAudio(videoId: videoId)
        WatchDownloadCatalog.shared.remove(videoId: videoId)
    }

    private func clearState() {
        isDownloading = false
        progress = 0
        activeDownloadTitle = nil
        activeDownloadChannel = nil
        activeItem = nil
    }
}

// MARK: - URLSession Delegate

private final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private static let backgroundSessionID = "uk.co.wunsch.iarchivist.watch.download"

    var backgroundCompletionHandler: (@Sendable () -> Void)?

    private var continuation: CheckedContinuation<Void, Error>?
    private var activeItem: WatchDownloadItem?
    private var storage: WatchAudioStorage?
    private var onProgress: ((Double) -> Void)?
    private var onComplete: ((WatchDownload?) -> Void)?

    private var _backgroundSession: URLSession?

    var backgroundSession: URLSession {
        if let session = _backgroundSession {
            return session
        }
        let config = URLSessionConfiguration.background(
            withIdentifier: Self.backgroundSessionID
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        let session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
        _backgroundSession = session
        return session
    }

    func resetSession() {
        _backgroundSession = nil
        continuation = nil
        activeItem = nil
        storage = nil
        onProgress = nil
        onComplete = nil
    }

    func configure(
        continuation: CheckedContinuation<Void, Error>,
        item: WatchDownloadItem,
        storage: WatchAudioStorage,
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (WatchDownload?) -> Void
    ) {
        self.continuation = continuation
        self.activeItem = item
        self.storage = storage
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress?(fraction)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let item = activeItem, let storage else {
            continuation?.resume(throwing: WatchDownloadError.downloadFailed)
            continuation = nil
            onComplete?(nil)
            return
        }

        let outputURL = storage.localFileURL(for: item.videoId)
        try? FileManager.default.removeItem(at: outputURL)

        do {
            try FileManager.default.moveItem(at: location, to: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: location)
            continuation?.resume(throwing: WatchDownloadError.exportFailed)
            continuation = nil
            onComplete?(nil)
            return
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes?[.size] as? Int

        let record = WatchDownload(
            id: item.videoId,
            title: item.title,
            channelName: item.channelName,
            duration: item.duration,
            durationStr: item.durationStr,
            fileSize: fileSize,
            downloadedAt: Date().timeIntervalSince1970,
            lastPlayedPosition: 0,
            thumbPath: item.thumbPath
        )

        onComplete?(record)
        continuation?.resume()
        continuation = nil
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            onComplete?(nil)
        }
    }

    func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        Task { @MainActor in
            handler?()
        }
    }
}
#endif
