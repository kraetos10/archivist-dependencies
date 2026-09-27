import ArchivistComponents
import ComposableArchitecture
import Foundation

/// On-device media lookups the video detail feature needs: where an offline
/// download lives, and whether the playback cache already holds a video.
///
/// A dependency so the reducer never touches the file system or
/// `PlaybackCache`'s statics directly — tests override it rather than
/// reading the real disk.
public struct OfflineMediaClient: Sendable {
    /// File URL of the offline copy of `videoId`. Whether the file exists is
    /// `LocalVideoStorage.isDownloaded`'s business; this only says where it
    /// would be.
    public var localFileURL: @Sendable (_ videoId: String) -> URL
    /// Whether the playback cache holds a complete copy of `videoId`.
    public var isCached: @Sendable (_ videoId: String) -> Bool

    public init(
        localFileURL: @escaping @Sendable (_ videoId: String) -> URL,
        isCached: @escaping @Sendable (_ videoId: String) -> Bool
    ) {
        self.localFileURL = localFileURL
        self.isCached = isCached
    }
}

extension OfflineMediaClient: DependencyKey {
    /// Mirrors `LocalVideoStorage.fileURL(for:)`, which is internal to
    /// `ArchivistNetworking`: `Documents/OfflineVideos/<id>.mp4`.
    public static var liveValue: Self {
        OfflineMediaClient(
            localFileURL: { videoId in
                URL.documentsDirectory
                    .appending(path: "OfflineVideos", directoryHint: .isDirectory)
                    .appending(path: "\(videoId).mp4")
            },
            isCached: { videoId in
                PlaybackCache.isCached(videoId: videoId)
            }
        )
    }

    public static var testValue: Self {
        OfflineMediaClient(
            localFileURL: { videoId in
                reportIssue("Unimplemented: 'OfflineMediaClient.localFileURL'")
                return URL(filePath: "/unimplemented/\(videoId).mp4")
            },
            isCached: { _ in
                reportIssue("Unimplemented: 'OfflineMediaClient.isCached'")
                return false
            }
        )
    }

    public static var previewValue: Self {
        OfflineMediaClient(
            localFileURL: { URL(filePath: "/preview/\($0).mp4") },
            isCached: { _ in false }
        )
    }
}

public extension DependencyValues {
    var offlineMedia: OfflineMediaClient {
        get { self[OfflineMediaClient.self] }
        set { self[OfflineMediaClient.self] = newValue }
    }
}
