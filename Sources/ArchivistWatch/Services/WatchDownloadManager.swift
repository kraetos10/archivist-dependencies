#if os(watchOS)
import ArchivistNetworking
import Foundation

public struct WatchDownloadItem: Codable, Equatable, Sendable {
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

    /// Encoded into the download task's `taskDescription`, which the system
    /// keeps with a background task, so a download that finishes after the
    /// app was relaunched still knows what it was.
    var taskDescription: String? {
        (try? JSONEncoder().encode(self)).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    init?(taskDescription: String?) {
        guard let taskDescription,
              let item = try? JSONDecoder().decode(Self.self, from: Data(taskDescription.utf8)) else {
            return nil
        }
        self = item
    }

    func record(
        fileSize: Int?,
        downloadedAt: Date
    ) -> WatchDownload {
        WatchDownload(
            id: videoId,
            title: title,
            channelName: channelName,
            duration: duration,
            durationStr: durationStr,
            fileSize: fileSize,
            downloadedAt: downloadedAt.timeIntervalSince1970,
            lastPlayedPosition: 0,
            thumbPath: thumbPath
        )
    }
}

public enum WatchDownloadError: Error, Equatable {
    case alreadyDownloading
    case noMediaURL
    case httpStatus(Int)
    case exportFailed
    case downloadFailed
    case cancelled

    /// Whether a response is a real file rather than an error page.
    static func validate(_ response: URLResponse?) -> WatchDownloadError? {
        guard let http = response as? HTTPURLResponse else { return .downloadFailed }
        return (200..<300).contains(http.statusCode) ? nil : .httpStatus(http.statusCode)
    }
}

/// Downloads audio for offline playback on a background `URLSession`.
///
/// Its delegate queue is the main queue, so every delegate callback runs on
/// the main actor and all bookkeeping is main-actor state — no locks. The
/// session is created once and kept: cancelling cancels tasks, never the
/// session, so a session with the same identifier is never recreated while
/// the old one is still being torn down.
@MainActor
@Observable
public final class WatchDownloadManager: NSObject {
    public private(set) var progress: Double = 0
    public private(set) var isDownloading = false
    public private(set) var activeDownloadTitle: String?
    public private(set) var activeDownloadChannel: String?

    @ObservationIgnored private let sessionIdentifier: String
    @ObservationIgnored private let storage: WatchAudioStorage
    @ObservationIgnored private let catalog: WatchDownloadCatalog
    @ObservationIgnored private var session: URLSession?
    @ObservationIgnored private var continuations: [Int: CheckedContinuation<Void, any Error>] = [:]
    @ObservationIgnored private var failures: [Int: WatchDownloadError] = [:]
    @ObservationIgnored private var backgroundCompletionHandler: (@MainActor () -> Void)?

    public init(
        sessionIdentifier: String,
        catalog: WatchDownloadCatalog,
        storage: WatchAudioStorage = WatchAudioStorage()
    ) {
        self.sessionIdentifier = sessionIdentifier
        self.catalog = catalog
        self.storage = storage
    }

    /// Reattaches to the background session after a launch, so downloads the
    /// system finished (or is still running) while the app was away are
    /// delivered, and an in-flight one shows as downloading again.
    public func reconnectBackgroundSession() async {
        let tasks = await backgroundSession.allTasks
        guard !isDownloading,
              let task = tasks.first(where: { $0.state == .running }),
              let item = WatchDownloadItem(taskDescription: task.taskDescription) else { return }
        begin(item)
    }

    public func handleBackgroundSessionCompletion(_ handler: @escaping @MainActor () -> Void) {
        backgroundCompletionHandler = handler
        _ = backgroundSession
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

        var request = URLRequest(url: mediaURL)
        if config.isServerURL(mediaURL) {
            for (key, value) in config.authHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        begin(video)
        let session = backgroundSession
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let task = session.downloadTask(with: request)
            task.taskDescription = video.taskDescription
            continuations[task.taskIdentifier] = continuation
            task.resume()
        }
    }

    /// Cancels the running download. Its continuation is resumed from
    /// `didCompleteWithError` with the cancellation, so nothing is leaked.
    public func cancelDownload() {
        session?.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    public func deleteDownload(videoId: String) throws {
        try storage.deleteAudio(videoId: videoId)
        catalog.remove(videoId: videoId)
    }

    private var backgroundSession: URLSession {
        if let session {
            return session
        }
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: .main
        )
        self.session = session
        return session
    }

    private func begin(_ item: WatchDownloadItem) {
        isDownloading = true
        progress = 0
        activeDownloadTitle = item.title
        activeDownloadChannel = item.channelName
    }

    private func clearState() {
        isDownloading = false
        progress = 0
        activeDownloadTitle = nil
        activeDownloadChannel = nil
    }

    private func finish(
        location: URL,
        task: URLSessionDownloadTask
    ) {
        if let failure = WatchDownloadError.validate(task.response) {
            failures[task.taskIdentifier] = failure
            return
        }
        guard let item = WatchDownloadItem(taskDescription: task.taskDescription) else {
            failures[task.taskIdentifier] = .downloadFailed
            return
        }
        do {
            _ = try storage.store(downloadedFile: location, videoId: item.videoId)
        } catch {
            failures[task.taskIdentifier] = .exportFailed
            return
        }
        catalog.add(
            item.record(
                fileSize: storage.fileSize(videoId: item.videoId),
                downloadedAt: .now
            )
        )
    }

    private func complete(
        task: URLSessionTask,
        error: (any Error)?
    ) {
        let failure = failures.removeValue(forKey: task.taskIdentifier)
        let continuation = continuations.removeValue(forKey: task.taskIdentifier)
        clearState()

        if let error {
            let isCancelled = (error as? URLError)?.code == .cancelled
            continuation?.resume(throwing: isCancelled ? WatchDownloadError.cancelled : error)
        } else if let failure {
            continuation?.resume(throwing: failure)
        } else {
            continuation?.resume()
        }
    }

    private func invalidate(error: (any Error)?) {
        session = nil
        let pending = continuations
        continuations = [:]
        failures = [:]
        clearState()
        for continuation in pending.values {
            continuation.resume(throwing: error ?? WatchDownloadError.cancelled)
        }
    }

    private func finishBackgroundEvents() {
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        handler?()
    }
}

extension WatchDownloadManager: URLSessionDownloadDelegate {
    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        MainActor.assumeIsolated {
            progress = fraction
        }
    }

    /// The file at `location` is deleted as soon as this returns, so it is
    /// moved into place synchronously here.
    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        MainActor.assumeIsolated {
            finish(location: location, task: downloadTask)
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        MainActor.assumeIsolated {
            complete(task: task, error: error)
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        didBecomeInvalidWithError error: (any Error)?
    ) {
        MainActor.assumeIsolated {
            invalidate(error: error)
        }
    }

    nonisolated public func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        MainActor.assumeIsolated {
            finishBackgroundEvents()
        }
    }
}
#endif
