#if os(watchOS)
import ArchivistNetworking
import Foundation

/// Everything a video row shows, worked out ahead of time so the row view
/// only lays it out.
public struct WatchVideoRowModel: Equatable, Sendable {
    public let title: String
    public let thumbnailURL: URL?
    public let isWatched: Bool
    public let isDownloaded: Bool
    public let watchProgress: Double
    public let subtitle: String?

    public init(
        title: String,
        thumbnailURL: URL?,
        isWatched: Bool,
        isDownloaded: Bool,
        watchProgress: Double,
        subtitle: String?
    ) {
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.isWatched = isWatched
        self.isDownloaded = isDownloaded
        self.watchProgress = watchProgress
        self.subtitle = subtitle
    }

    public init(
        video: VideoResponse,
        config: ServerConfig,
        isDownloaded: Bool
    ) {
        self.init(
            title: video.title,
            thumbnailURL: video.vidThumbUrl.flatMap(config.fullURL(for:)),
            isWatched: video.isWatched,
            isDownloaded: isDownloaded,
            watchProgress: video.watchProgress,
            subtitle: Self.subtitle(
                watchProgress: video.watchProgress,
                remainingSeconds: video.remainingSeconds,
                durationStr: video.durationStr
            )
        )
    }

    /// Time left for a started video, otherwise its length.
    static func subtitle(
        watchProgress: Double,
        remainingSeconds: Int?,
        durationStr: String?
    ) -> String? {
        if watchProgress > 0, let remainingSeconds {
            return remainingText(seconds: remainingSeconds)
        }
        return durationStr
    }

    static func remainingText(seconds: Int) -> String {
        let duration = DurationText.abbreviated(seconds: seconds)
        return String(localized: "video.remaining \(duration)", bundle: .module)
    }
}
#endif
