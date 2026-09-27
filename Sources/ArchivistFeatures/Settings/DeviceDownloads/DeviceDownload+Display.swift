#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import Foundation

extension DeviceDownload {
    var isCompleted: Bool {
        status == .completed
    }

    /// The YouTube page for the share sheet.
    var shareURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }

    /// Download progress or a retry hint, shown where published dates go
    /// on server cards.
    var statusText: String? {
        switch status {
        case .downloading:
            progress > 0
                ? progress.formatted(.percent.precision(.fractionLength(0)))
                : String.localised("video.downloading", table: .videos)
        case .failed:
            String.localised("generic.tapToRetry", table: .generic)
        case .completed, .none:
            nil
        }
    }

    var cardData: CardData {
        CardData(
            videoId: id,
            title: title,
            channelName: channelName,
            thumbPath: thumbUrl,
            duration: nil,
            publishedRelative: statusText,
            isWatched: false,
            isPartiallyWatched: false,
            watchProgress: 0,
            isPending: false,
            isDownloaded: isCompleted,
            fileSize: fileSize.map { Int64($0).formatted(.byteCount(style: .file)) }
        )
    }

    /// A minimal video built from what's stored locally, enough for the
    /// detail screen to play the file offline.
    var offlineVideo: VideoResponse {
        VideoResponse(
            videoId: id,
            title: title,
            description: nil,
            category: nil,
            channel: VideoChannel(
                channelId: "",
                channelName: channelName,
                channelActive: nil,
                channelBannerUrl: nil,
                channelThumbUrl: nil,
                channelTvartUrl: nil,
                channelDescription: nil,
                channelLastRefresh: nil,
                channelSubs: nil,
                channelSubscribed: nil,
                channelTags: nil,
                channelTabs: nil
            ),
            published: nil,
            dateDownloaded: nil,
            vidLastRefresh: nil,
            vidThumbUrl: thumbUrl,
            vidType: nil,
            active: nil,
            mediaUrl: nil,
            mediaSize: nil,
            player: nil,
            stats: nil,
            subtitles: nil,
            streams: nil,
            tags: nil,
            commentCount: nil
        )
    }
}
#endif
