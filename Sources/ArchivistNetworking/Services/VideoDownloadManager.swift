import Dependencies
import Foundation

public nonisolated protocol VideoDownloadManagerType: Sendable {
    func download(
        url: URL,
        videoId: String,
        expectedSize: Int64?,
        authHeaders: [String: String],
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
}

public struct VideoDownloadManager: VideoDownloadManagerType, Sendable {
    private let progress: Progress

    public init(progress: Progress) {
        self.progress = progress
    }

    public func download(
        url: URL,
        videoId: String,
        expectedSize: Int64?,
        authHeaders: [String: String],
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        @Dependency(\.localVideoStorage) var storage
        var request = URLRequest(url: url)
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        // Don't pass delegate to download(for:) — the session-level delegate
        // handles didWriteData for progress. Passing it here as a task delegate
        // would override the session delegate and skip progress callbacks.
        let (tempURL, response) = try await session.download(
            for: request,
            delegate: delegate
        )

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try storage.moveDownloadedFile(from: tempURL, videoId: videoId)
    }
}

final class DownloadDelegate: NSObject, URLSessionTaskDelegate {
    private let progress: Progress

    init(progress: Progress) {
        self.progress = progress
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        progress.addChild(task.progress, withPendingUnitCount: 100)
    }
}
