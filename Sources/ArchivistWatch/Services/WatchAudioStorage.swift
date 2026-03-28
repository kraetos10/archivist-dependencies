#if os(watchOS)
import Foundation

public struct WatchAudioStorage {
    public init() {}

    private var audioDirectory: URL {
        URL.documentsDirectory.appendingPathComponent("OfflineAudio", isDirectory: true)
    }

    public func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: audioDirectory,
            withIntermediateDirectories: true
        )
    }

    public func localFileURL(for videoId: String) -> URL {
        audioDirectory.appendingPathComponent("\(videoId).m4a")
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

    public func totalStorageUsed() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: audioDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    public func formattedStorageUsed() -> String {
        let bytes = totalStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
#endif
