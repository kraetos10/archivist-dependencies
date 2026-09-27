import ArchivistNetworking
import Foundation

extension PlayNextItem {
    /// Server URL of the queued video's thumbnail.
    func thumbnailURL(config: ServerConfig) -> URL? {
        thumbUrl.flatMap { config.fullURL(for: $0) }
    }

    /// "12:34 · 2 weeks ago", or whichever half is known.
    var detailsLine: String? {
        let parts = [duration, publishedRelative].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
