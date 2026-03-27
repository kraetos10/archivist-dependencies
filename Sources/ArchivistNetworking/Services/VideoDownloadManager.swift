import Dependencies
import Foundation

public nonisolated protocol VideoDownloadManagerType: Sendable {
    func download(
        url: URL,
        videoId: String,
        authHeaders: [String: String],
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
}

public struct VideoDownloadManager: VideoDownloadManagerType, Sendable {
    public init() {}

    public func download(
        url: URL,
        videoId: String,
        authHeaders: [String: String],
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        @Dependency(\.localVideoStorage) var storage
        var request = URLRequest(url: url)
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let delegate = DownloadDelegate(onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (tempURL, response) = try await session.download(for: request, delegate: delegate)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try storage.moveDownloadedFile(from: tempURL, videoId: videoId)
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress(progress)
        } else {
            // Content-Length unknown — report bytes written so UI can show activity
            onProgress(-1)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled by the async download(for:delegate:) call
    }
}
