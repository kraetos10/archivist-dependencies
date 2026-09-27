import ArchivistNetworking
import Foundation

extension VideoResponse {
    /// A copy with the watched flag set, for optimistic updates before the
    /// server confirms. Everything else is carried over unchanged.
    func settingWatched(_ isWatched: Bool) -> VideoResponse {
        VideoResponse(
            videoId: videoId,
            title: title,
            description: description,
            category: category,
            channel: channel,
            published: published,
            dateDownloaded: dateDownloaded,
            vidLastRefresh: vidLastRefresh,
            vidThumbUrl: vidThumbUrl,
            vidType: vidType,
            active: active,
            mediaUrl: mediaUrl,
            mediaSize: mediaSize,
            player: VideoPlayer(
                watched: isWatched,
                watchedDate: player?.watchedDate,
                duration: player?.duration,
                durationStr: player?.durationStr,
                progress: player?.progress,
                position: player?.position
            ),
            stats: stats,
            subtitles: subtitles,
            streams: streams,
            tags: tags,
            commentCount: commentCount
        )
    }
}
