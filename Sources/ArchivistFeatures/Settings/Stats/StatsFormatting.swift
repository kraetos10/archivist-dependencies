import ArchivistComponents
import ArchivistNetworking
import Foundation

// Display text for the stats rows, worked out here so the section views
// only lay out what they're given.

extension VideoStatsResponse {
    var mediaSizeText: String {
        Int64(totalSize ?? 0).formatted(.byteCount(style: .binary))
    }

    var durationText: String {
        guard let totalDuration, totalDuration > 0 else {
            return String.localised("stats.notAvailable", table: .settings)
        }
        return Duration.seconds(totalDuration).formatted(
            .units(allowed: [.days, .hours, .minutes, .seconds], width: .abbreviated)
        )
    }
}

extension WatchStatsResponse {
    private var total: Int {
        (watched ?? 0) + (unwatched ?? 0)
    }

    var watchedText: String {
        Self.countWithShare(watched ?? 0, of: total)
    }

    var unwatchedText: String {
        Self.countWithShare(unwatched ?? 0, of: total)
    }

    /// "1,204 (62.5%)".
    private static func countWithShare(
        _ count: Int,
        of total: Int
    ) -> String {
        let share = total > 0 ? Double(count) / Double(total) : 0
        let percent = share.formatted(.percent.precision(.fractionLength(1)))
        return String.localised("stats.countWithShare \(count) \(percent)", table: .settings)
    }
}

extension DownloadHistResponse {
    /// The day as a medium date; the raw string when it doesn't parse.
    var dateText: String {
        guard let date else { return "" }
        guard let parsed = try? Date(date, strategy: Date.ISO8601FormatStyle().year().month().day()) else {
            return date
        }
        return parsed.formatted(date: .abbreviated, time: .omitted)
    }

    var countText: String {
        let count = count ?? 0
        return count > 0 ? "+\(count.formatted())" : "–"
    }

    var hasDownloads: Bool {
        (count ?? 0) > 0
    }
}

extension BiggestChannelResponse {
    var videoCountText: String {
        String.localised("stats.channelVideoCount \(docCount ?? 0)", table: .settings)
    }

    func thumbnailURL(config: ServerConfig) -> URL? {
        guard let id else { return nil }
        return config.fullURL(for: "/cache/channels/\(id)_thumb.jpg")
    }
}
