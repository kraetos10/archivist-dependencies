import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct LocalVideoStorage: Sendable {
    public var isDownloaded: @Sendable (_ videoId: String) -> Bool = { _ in false }
    public var deleteVideo: @Sendable (_ videoId: String) throws -> Void
    public var deleteAllVideos: @Sendable () throws -> Void
    public var moveDownloadedFile: @Sendable (
        _ from: URL,
        _ videoId: String
    ) throws -> URL
}

extension LocalVideoStorage {
    static var videosDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent("OfflineVideos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileURL(for videoId: String) -> URL {
        videosDirectory.appendingPathComponent("\(videoId).mp4")
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
}

extension LocalVideoStorage: DependencyKey {
    public static let liveValue = LocalVideoStorage(
        isDownloaded: { videoId in
            FileManager.default.fileExists(atPath: fileURL(for: videoId).path)
        },
        deleteVideo: { videoId in
            let url = fileURL(for: videoId)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        },
        deleteAllVideos: {
            let dir = videosDirectory
            if FileManager.default.fileExists(atPath: dir.path) {
                let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                for file in contents {
                    try FileManager.default.removeItem(at: file)
                }
            }
        },
        moveDownloadedFile: { tempURL, videoId in
            let destination = fileURL(for: videoId)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            return destination
        }
    )

    public static var testValue: LocalVideoStorage { LocalVideoStorage() }
}
