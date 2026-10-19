#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import Foundation

extension YouTubeVideo {
    /// "1.2M views · 2 weeks ago", skipping whichever half is missing.
    var detailText: String {
        let views = viewsText.map { String.localised("discover.views \($0)", table: .discover) }
        return [views, publishedText].compactMap { $0 }.joined(separator: " · ")
    }
}

extension YouTubeChannel {
    /// "1.2M subscribers · 340 videos", skipping whichever half is missing.
    var statsText: String {
        let subscribers = subscribersText.map {
            String.localised("discover.subscribers \($0)", table: .discover)
        }
        let videos = videoCount.map {
            String.localised("discover.videoCount \($0)", table: .discover)
        }
        return [subscribers, videos].compactMap { $0 }.joined(separator: " · ")
    }
}
#endif
