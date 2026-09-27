import Dependencies
import Foundation

public nonisolated protocol VideoDownloadManagerType: Sendable {
    /// Downloads `url` into local storage for `videoId`. Progress is reported
    /// through the `Progress` the manager was created with, not a callback.
    func download(
        url: URL,
        videoId: String,
        authHeaders: [String: String]
    ) async throws -> URL
}

extension VideoDownloadManagerType {
    /// `expectedSize` and `onProgress` were never read — progress flows
    /// through the manager's `Progress`. Kept so existing callers compile.
    @available(
        *,
        deprecated,
        message: "Use download(url:videoId:authHeaders:); observe the manager's Progress instead."
    )
    public func download(
        url: URL,
        videoId: String,
        expectedSize: Int64?,
        authHeaders: [String: String],
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try await download(
            url: url,
            videoId: videoId,
            authHeaders: authHeaders
        )
    }
}

public nonisolated struct VideoDownloadManager: VideoDownloadManagerType {
    private let progress: Progress

    public init(progress: Progress) {
        self.progress = progress
    }

    public func download(
        url: URL,
        videoId: String,
        authHeaders: [String: String]
    ) async throws -> URL {
        @Dependency(\.localVideoStorage) var storage
        var request = URLRequest(url: url)
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // The session-level delegate adopts each task's `Progress` as a child
        // of ours in `didCreateTask`, which is how progress reaches callers.
        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (tempURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw URLError(.badServerResponse)
        }

        return try storage.moveDownloadedFile(from: tempURL, videoId: videoId)
    }
}

private nonisolated final class DownloadDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let progress: Progress

    init(progress: Progress) {
        self.progress = progress
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        progress.addChild(task.progress, withPendingUnitCount: 100)
    }
}
