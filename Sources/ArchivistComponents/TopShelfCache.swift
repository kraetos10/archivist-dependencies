import ArchivistNetworking
import Dependencies
import Foundation

public enum TopShelfCache {
    /// The app group shared with the Top Shelf extension. Injected by the
    /// app at launch — the package doesn't know the app's identifiers.
    private static let appGroupID = LockIsolated<String?>(nil)

    /// Call once at launch, before anything is cached.
    public static func configure(appGroupID: String) {
        self.appGroupID.setValue(appGroupID)
    }

    public static var cacheDirectory: URL? {
        guard let appGroupID = appGroupID.value else {
            reportIssue("TopShelfCache is not configured. Call 'TopShelfCache.configure(appGroupID:)' at launch.")
            return nil
        }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "TopShelfCache", directoryHint: .isDirectory)
    }

    public static func cacheTopShelfContent(
        videos: [VideoResponse],
        serverConfig: ServerConfig
    ) {
        guard let cacheDir = cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // Cache video metadata as JSON
        let items = videos.prefix(20).map { video in
            TopShelfItem(
                id: video.videoId,
                title: video.title,
                thumbFileName: "\(video.videoId).jpg"
            )
        }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: cacheDir.appendingPathComponent("videos.json"))
        }

        // Download and cache thumbnails
        Task.detached(priority: .background) {
            for video in videos.prefix(20) {
                guard let thumbPath = video.vidThumbUrl,
                      let thumbURL = serverConfig.fullURL(for: thumbPath) else { continue }

                let localFile = cacheDir.appendingPathComponent("\(video.videoId).jpg")
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

public struct TopShelfItem: Codable {
    public let id: String
    public let title: String
    public let thumbFileName: String

    public init(
        id: String,
        title: String,
        thumbFileName: String
    ) {
        self.id = id
        self.title = title
        self.thumbFileName = thumbFileName
    }
}
