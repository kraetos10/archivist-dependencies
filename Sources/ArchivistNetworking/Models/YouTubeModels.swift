import Foundation

/// A video returned by YouTube's Data API. Not an archive video: it carries
/// only what the API sends, and its `videoId` is what TubeArchivist's
/// add-to-queue endpoint takes.
public nonisolated struct YouTubeVideo: Sendable, Equatable, Identifiable, Hashable, Codable {
    public let videoId: String
    public let title: String
    public let channelId: String
    public let channelTitle: String
    public let thumbnailURL: URL?
    public let published: Date?
    public let durationSeconds: Int?
    public let viewCount: Int?

    public var id: String { videoId }

    public init(
        videoId: String,
        title: String,
        channelId: String,
        channelTitle: String,
        thumbnailURL: URL? = nil,
        published: Date? = nil,
        durationSeconds: Int? = nil,
        viewCount: Int? = nil
    ) {
        self.videoId = videoId
        self.title = title
        self.channelId = channelId
        self.channelTitle = channelTitle
        self.thumbnailURL = thumbnailURL
        self.published = published
        self.durationSeconds = durationSeconds
        self.viewCount = viewCount
    }

    /// "4:05", or "1:02:03" past the hour.
    public var durationText: String? {
        durationSeconds.map { DurationText.clock(seconds: Double($0)) }
    }

    /// "1.2M".
    public var viewsText: String? {
        viewCount.map { YouTubeCountText.compact($0) }
    }

    /// "2 weeks ago".
    public var publishedText: String? {
        published.map { PublishedDate.relative($0) }
    }
}

public nonisolated struct YouTubePlaylist: Sendable, Equatable, Identifiable, Hashable {
    public let playlistId: String
    public let title: String
    public let channelTitle: String
    public let thumbnailURL: URL?
    public let itemCount: Int?

    public var id: String { playlistId }

    public init(
        playlistId: String,
        title: String,
        channelTitle: String = "",
        thumbnailURL: URL? = nil,
        itemCount: Int? = nil
    ) {
        self.playlistId = playlistId
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailURL = thumbnailURL
        self.itemCount = itemCount
    }
}

public nonisolated struct YouTubeChannel: Sendable, Equatable, Identifiable, Hashable {
    public let channelId: String
    public let title: String
    public let channelDescription: String
    public let thumbnailURL: URL?
    public let subscriberCount: Int?
    public let videoCount: Int?

    public var id: String { channelId }

    public init(
        channelId: String,
        title: String,
        channelDescription: String = "",
        thumbnailURL: URL? = nil,
        subscriberCount: Int? = nil,
        videoCount: Int? = nil
    ) {
        self.channelId = channelId
        self.title = title
        self.channelDescription = channelDescription
        self.thumbnailURL = thumbnailURL
        self.subscriberCount = subscriberCount
        self.videoCount = videoCount
    }

    /// "1.2M".
    public var subscribersText: String? {
        subscriberCount.map { YouTubeCountText.compact($0) }
    }
}

/// One page of results plus the token for the next, `nil` on the last page.
public nonisolated struct YouTubePage<Item: Sendable & Equatable>: Sendable, Equatable {
    public let items: [Item]
    public let nextPageToken: String?

    public init(
        items: [Item],
        nextPageToken: String? = nil
    ) {
        self.items = items
        self.nextPageToken = nextPageToken
    }
}

public nonisolated enum YouTubeSearchOrder: String, Sendable, CaseIterable, Equatable {
    case relevance
    case date
    case viewCount
    case rating
}

/// Narrowing for a video search. `any` leaves a filter off.
public nonisolated struct YouTubeSearchFilters: Sendable, Equatable {
    /// YouTube's own buckets: short is under 4 minutes, medium 4 to 20, long over 20.
    public enum Duration: String, Sendable, CaseIterable, Equatable {
        case any
        case short
        case medium
        case long

        /// The `videoDuration` parameter, or `nil` for any.
        public var apiValue: String? { self == .any ? nil : rawValue }
    }

    public enum Uploaded: String, Sendable, CaseIterable, Equatable {
        case any
        case today
        case week
        case month
        case year

        /// The earliest upload the filter allows, or `nil` for any.
        public func earliest(relativeTo now: Date) -> Date? {
            let component: Calendar.Component
            switch self {
            case .any: return nil
            case .today: component = .day
            case .week: component = .weekOfYear
            case .month: component = .month
            case .year: component = .year
            }
            // UTC, so "a week ago" is the same instant in every time zone
            // and doesn't stretch or shrink across a daylight-saving change.
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            return calendar.date(byAdding: component, value: -1, to: now)
        }
    }

    public var duration: Duration
    public var uploaded: Uploaded

    public init(
        duration: Duration = .any,
        uploaded: Uploaded = .any
    ) {
        self.duration = duration
        self.uploaded = uploaded
    }

    public var isActive: Bool {
        duration != .any || uploaded != .any
    }
}

public nonisolated enum YouTubeCountText {
    /// "1.2M", "34K", "980".
    public static func compact(_ count: Int) -> String {
        count.formatted(.number.notation(.compactName))
    }
}

/// What can go wrong talking to YouTube, split by what the user can do about
/// it: each case has a different remedy in the Discover screen.
public nonisolated enum YouTubeError: Error, Equatable, Sendable {
    /// The key was rejected (typo, deleted, or restricted away from this API).
    case invalidKey
    /// The key's project hasn't enabled the YouTube Data API v3.
    case apiNotEnabled
    /// Today's free allowance is spent; it resets at midnight Pacific.
    case quotaExceeded
    /// Anything else Google rejected, with its message for diagnostics.
    case rejected(String)
    /// YouTube has no such chart (a trending category some regions lack).
    case notFound
    case network
    case decodingFailed

    /// Maps a non-2xx response. Google's error body lists a machine-readable
    /// `reason` per error, and for a bad key the reason is only in `details`.
    public init(
        statusCode: Int,
        body: Data
    ) {
        let envelope = try? JSONDecoder().decode(GoogleErrorEnvelope.self, from: body)
        let reasons = Set(
            (envelope?.error.errors?.compactMap(\.reason) ?? [])
                + (envelope?.error.details?.compactMap(\.reason) ?? [])
        )
        let message = envelope?.error.message ?? ""

        if !reasons.isDisjoint(with: ["quotaExceeded", "dailyLimitExceeded", "rateLimitExceeded"]) {
            self = .quotaExceeded
        } else if !reasons.isDisjoint(with: ["accessNotConfigured", "SERVICE_DISABLED"]) {
            self = .apiNotEnabled
        } else if !reasons.isDisjoint(with: ["keyInvalid", "API_KEY_INVALID"])
                    || message.localizedCaseInsensitiveContains("API key not valid") {
            self = .invalidKey
        } else if reasons.contains("API_KEY_SERVICE_BLOCKED") || reasons.contains("ipRefererBlocked") {
            self = .invalidKey
        } else if !reasons.isDisjoint(with: ["videoChartNotFound", "notFound"]) {
            self = .notFound
        } else {
            self = .rejected(message.isEmpty ? "HTTP \(statusCode)" : message)
        }
    }
}

nonisolated struct GoogleErrorEnvelope: Decodable {
    struct Body: Decodable {
        struct Item: Decodable {
            let reason: String?
        }

        let message: String?
        let errors: [Item]?
        let details: [Item]?
    }

    let error: Body
}
