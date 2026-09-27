#if os(watchOS)
import Foundation

/// Where downloaded audio lives on disk. The directory is injectable so
/// tests can point it at a temporary folder.
public struct WatchAudioStorage: Sendable {
    public let directory: URL

    public init(directory: URL = URL.documentsDirectory.appending(path: "OfflineAudio", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    public func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    public func localFileURL(for videoId: String) -> URL {
        directory.appending(path: "\(videoId).m4a")
    }

    public func isDownloaded(videoId: String) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: videoId).path)
    }

    public func deleteAudio(videoId: String) throws {
        let url = localFileURL(for: videoId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Moves a finished download into place, replacing any older copy.
    public func store(
        downloadedFile location: URL,
        videoId: String
    ) throws -> URL {
        try ensureDirectoryExists()
        let destination = localFileURL(for: videoId)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: location, to: destination)
        return destination
    }

    public func fileSize(videoId: String) -> Int? {
        let url = localFileURL(for: videoId)
        return (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}
#endif
