import ArchivistNetworking
import Foundation

extension PlaylistEntry {
    /// The entry's watch page on YouTube, for sharing. `nil` for an entry
    /// without a video id.
    var youtubeWatchURL: URL? {
        youtubeId.flatMap { URL(string: "https://www.youtube.com/watch?v=\($0)") }
    }
}
