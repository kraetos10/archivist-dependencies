#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import Foundation

/// A row of videos shown above Discover's trending grid.
public struct DiscoverShelf: Equatable, Sendable, Identifiable, Codable {
    public var id: String
    public var title: String
    public var videos: [YouTubeVideo]

    public init(
        id: String,
        title: String,
        videos: [YouTubeVideo]
    ) {
        self.id = id
        self.title = title
        self.videos = videos
    }
}

/// YouTube's video categories that have a trending chart, for the chips above
/// Trending. The raw value is YouTube's category ID.
public enum DiscoverCategory: String, CaseIterable, Sendable, Identifiable {
    case music = "10"
    case gaming = "20"
    case entertainment = "24"
    case scienceTech = "28"
    case news = "25"
    case sports = "17"
    case film = "1"
    case comedy = "23"
    case education = "27"
    case howTo = "26"
    case travel = "19"
    case autos = "2"

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .music: String.localised("discover.category.music", table: .discover)
        case .gaming: String.localised("discover.category.gaming", table: .discover)
        case .entertainment: String.localised("discover.category.entertainment", table: .discover)
        case .scienceTech: String.localised("discover.category.scienceTech", table: .discover)
        case .news: String.localised("discover.category.news", table: .discover)
        case .sports: String.localised("discover.category.sports", table: .discover)
        case .film: String.localised("discover.category.film", table: .discover)
        case .comedy: String.localised("discover.category.comedy", table: .discover)
        case .education: String.localised("discover.category.education", table: .discover)
        case .howTo: String.localised("discover.category.howTo", table: .discover)
        case .travel: String.localised("discover.category.travel", table: .discover)
        case .autos: String.localised("discover.category.autos", table: .discover)
        }
    }
}

/// What the archive says the user likes, taken from what they've watched.
///
/// YouTube's API has no personalised recommendations, so Discover's "for
/// you" shelves are built from this instead: the channels watched most, and
/// a couple of recent videos to find more like.
struct DiscoverTaste: Equatable, Sendable {
    struct Channel: Equatable, Sendable {
        var id: String
        var name: String
        var watchedCount: Int
    }

    struct Seed: Equatable, Sendable {
        var videoId: String
        var title: String
    }

    static let channelLimit = 5
    static let seedLimit = 2

    var channels: [Channel]
    var seeds: [Seed]
    var watchedIds: Set<String>

    /// `watched` is newest first, as the server returns it.
    init(watched: [VideoResponse]) {
        var counts: [String: Channel] = [:]
        var firstSeen: [String] = []
        for video in watched {
            let id = video.channelId
            if var existing = counts[id] {
                existing.watchedCount += 1
                counts[id] = existing
            } else {
                counts[id] = Channel(id: id, name: video.channelName, watchedCount: 1)
                firstSeen.append(id)
            }
        }
        // Most watched first; a tie goes to whichever was watched more recently.
        channels = firstSeen
            .compactMap { counts[$0] }
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.watchedCount != rhs.element.watchedCount
                    ? lhs.element.watchedCount > rhs.element.watchedCount
                    : lhs.offset < rhs.offset
            }
            .prefix(Self.channelLimit)
            .map(\.element)

        // One seed per channel, so two shelves don't both mean the same thing.
        var seedChannels: Set<String> = []
        seeds = watched
            .filter { seedChannels.insert($0.channelId).inserted }
            .prefix(Self.seedLimit)
            .map { Seed(videoId: $0.videoId, title: $0.title) }
        watchedIds = Set(watched.map(\.videoId))
    }

    var isEmpty: Bool { channels.isEmpty }
}

enum DiscoverShelves {
    static let channelShelfLimit = 15
    static let perChannelLimit = 4

    /// The words to search for "more like this" from a video's title: the
    /// part before a `|` or `—` credit, without hashtags, bracketed notes
    /// or a trailing channel name.
    static func searchQuery(fromTitle title: String) -> String {
        var text = title
        for separator in ["|", " — ", " - ", "–"] {
            if let range = text.range(of: separator) {
                text = String(text[..<range.lowerBound])
            }
        }
        let words = text
            .split(whereSeparator: \.isWhitespace)
            .filter { !$0.hasPrefix("#") }
            .joined(separator: " ")
        let withoutBrackets = words.replacing(/[\(\[][^\)\]]*[\)\]]/, with: "")
        let cleaned = withoutBrackets.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(60))
    }

    /// The latest uploads of the channels watched most, newest first, with
    /// anything already watched left out and no one channel crowding the row.
    static func channelShelf(
        uploads: [[YouTubeVideo]],
        excluding watched: Set<String>
    ) -> DiscoverShelf? {
        var seen = watched
        let merged = uploads
            .flatMap { channel in
                channel
                    .filter { !watched.contains($0.videoId) }
                    .prefix(perChannelLimit)
            }
            .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
            .filter { seen.insert($0.videoId).inserted }
            .prefix(channelShelfLimit)
        guard !merged.isEmpty else { return nil }
        return DiscoverShelf(
            id: "channels",
            title: String.localised("discover.shelf.channels", table: .discover),
            videos: Array(merged)
        )
    }

    /// Search results for one watched video, without that video itself or
    /// anything already watched.
    static func becauseShelf(
        seed: DiscoverTaste.Seed,
        results: [YouTubeVideo],
        excluding watched: Set<String>
    ) -> DiscoverShelf? {
        let videos = results.filter { !watched.contains($0.videoId) && $0.videoId != seed.videoId }
        guard !videos.isEmpty else { return nil }
        return DiscoverShelf(
            id: "because-\(seed.videoId)",
            title: String.localised("discover.shelf.because \(seed.title)", table: .discover),
            videos: videos
        )
    }
}
#endif
