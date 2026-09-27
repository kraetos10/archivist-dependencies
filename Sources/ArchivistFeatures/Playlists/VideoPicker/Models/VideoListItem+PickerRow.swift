import ArchivistNetworking
import Foundation

extension VideoListItem {
    /// The picker row's title.
    var pickerTitle: String {
        switch self {
        case .video(let video): video.title
        case .download(let download): download.title ?? ""
        }
    }

    /// Channel, then (for a video on the server) its published date.
    var pickerSubtitle: String {
        switch self {
        case .video(let video):
            [video.channelName, video.publishedFormatted]
                .compactMap { $0 }
                .joined(separator: " · ")
        case .download(let download):
            download.channelName ?? ""
        }
    }

    /// Duration badge.
    var pickerBadge: String? {
        switch self {
        case .video(let video): video.durationStr
        case .download(let download): download.duration
        }
    }

    func pickerThumbnailURL(config: ServerConfig) -> URL? {
        switch self {
        case .video(let video):
            video.vidThumbUrl.flatMap { config.fullURL(for: $0) }
        case .download(let download):
            download.thumbURL(config: config)
        }
    }
}
