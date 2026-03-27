import ArchivistNetworking
import Foundation

public enum TopShelfCache {
    private static let appGroupID = "group.uk.co.wunsch.iarchivist"

    public static var cacheDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("TopShelfCache", isDirectory: true)
    }

    public static func cacheVideoThumbnails(videos: [(id: String, thumbPath: String?)], serverConfig: ServerConfig) {
        guard let cacheDir = cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        Task.detached(priority: .background) {
            for video in videos.prefix(20) {
                guard let thumbPath = video.thumbPath,
                      let thumbURL = serverConfig.fullURL(for: thumbPath) else { continue }

                let localFile = cacheDir.appendingPathComponent("\(video.id).jpg")
                guard !FileManager.default.fileExists(atPath: localFile.path) else { continue }

                var request = URLRequest(url: thumbURL)
                for (key, value) in serverConfig.authHeaders {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                if let (data, _) = try? await URLSession.shared.data(for: request) {
                    try? data.write(to: localFile)
                }
            }
        }
    }
}
