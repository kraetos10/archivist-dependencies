import Dependencies
import Foundation

public nonisolated protocol LocalVideoStorageType: Sendable {
    func localFileURL(for videoId: String) -> URL
    func isDownloaded(videoId: String) -> Bool
    func deleteVideo(videoId: String) throws
    func moveDownloadedFile(from tempURL: URL, videoId: String) throws -> URL
}

public nonisolated struct LocalVideoStorage: LocalVideoStorageType, Sendable {
    public init() {}

    private var videosDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent("OfflineVideos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public func localFileURL(for videoId: String) -> URL {
        videosDirectory.appendingPathComponent("\(videoId).mp4")
    }

    public func isDownloaded(videoId: String) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: videoId).path)
    }

    public func deleteVideo(videoId: String) throws {
        let url = localFileURL(for: videoId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public static func totalDownloadsSize() -> Int64 {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent("OfflineVideos", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    public func moveDownloadedFile(from tempURL: URL, videoId: String) throws -> URL {
        let destination = localFileURL(for: videoId)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }
}
