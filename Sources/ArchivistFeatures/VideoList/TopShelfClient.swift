import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture

/// Writes the tvOS Top Shelf cache (metadata JSON plus thumbnails).
///
/// A dependency so the video list never does file I/O from inside its
/// reducer: the write runs in an effect, and tests override it.
public struct TopShelfClient: Sendable {
    public var cache: @Sendable (
        _ videos: [VideoResponse],
        _ serverConfig: ServerConfig
    ) async -> Void

    public init(
        cache: @escaping @Sendable (
            _ videos: [VideoResponse],
            _ serverConfig: ServerConfig
        ) async -> Void
    ) {
        self.cache = cache
    }
}

extension TopShelfClient: DependencyKey {
    public static var liveValue: Self {
        TopShelfClient { videos, serverConfig in
            TopShelfCache.cacheTopShelfContent(
                videos: videos,
                serverConfig: serverConfig
            )
        }
    }

    public static var testValue: Self {
        TopShelfClient { _, _ in
            reportIssue("Unimplemented: 'TopShelfClient.cache'")
        }
    }

    public static var previewValue: Self {
        TopShelfClient { _, _ in }
    }
}

public extension DependencyValues {
    var topShelf: TopShelfClient {
        get { self[TopShelfClient.self] }
        set { self[TopShelfClient.self] = newValue }
    }
}
