import Foundation
import IdentifiedCollections

public nonisolated struct VideoResponse: Decodable, Sendable, Equatable, Identifiable, Hashable {
    public let videoId: String
    public let title: String
    public let description: String?
    public let category: [String]?
    public let channel: VideoChannel
    public let published: String?
    public let dateDownloaded: Int?
    public let vidLastRefresh: String?
    public let vidThumbUrl: String?
    public let vidType: VideoType?
    public let active: Bool?
    public let mediaUrl: String?
    public let mediaSize: Int?
    public let player: VideoPlayer?
    public let stats: VideoStats?
    public let subtitles: [VideoSubtitle]?
    public let streams: [VideoStream]?
    public let tags: [String]?
    public let commentCount: Int?

    public var id: String { videoId }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(videoId)
    }

    public var youtubeURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(videoId)")
    }

    public var channelName: String { channel.channelName }
    public var channelId: String { channel.channelId }
    public var durationStr: String? { player?.durationStr }

    public var remainingStr: String? {
        guard let position = player?.position, position > 0,
              let duration = player?.duration, duration > 0 else { return nil }
        let remaining = max(duration - Int(position), 0)
        return Self.remainingFormatter.string(from: TimeInterval(remaining))
            .map { "\($0) remaining" }
    }

    private static let remainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    public var isWatched: Bool { player?.watched ?? false }
    public var isPartiallyWatched: Bool { !isWatched && watchProgress > 0 }
    /// Strict "unwatched": never started and not marked watched. Partially
    /// watched videos belong in the continue-watching list, not here.
    public var isUnwatched: Bool { !isWatched && !isPartiallyWatched }

    /// Normalized watch progress from 0 to 1
    public var watchProgress: Double {
        if isWatched { return 0 }
        guard let progress = player?.progress, progress > 0 else { return 0 }
        return min(max(progress / 100, 0), 1)
    }

    /// Videos whose saved position is within this many seconds of the end
    /// are treated as finished and restart from the beginning, rather than
    /// resuming into the final moments (which immediately ends the video,
    /// appearing as a "skip to the end").
    private static let completionRemainingThreshold: Double = 15

    /// Best-known resume position in seconds. Prefers the server's
    /// `player.position` (set by `setProgress`), but falls back to
    /// `progress%` × `duration` so videos that only carry a percentage
    /// still resume correctly. Returns `nil` — i.e. start from the
    /// beginning — for completed videos and for positions within the
    /// final stretch of the video.
    public var resumePositionSeconds: Double? {
        // A completed video restarts from the beginning.
        if isWatched { return nil }

        let resume: Double
        if let position = player?.position, position > 0 {
            resume = position
        } else if let progress = player?.progress, progress > 0,
                  let duration = player?.duration, duration > 0 {
            resume = (progress / 100) * Double(duration)
        } else {
            return nil
        }
        guard resume > 0 else { return nil }

        // Treat a position within the final stretch as finished —
        // resuming there would land on (or seek straight to) the end.
        if let duration = player?.duration, duration > 0,
           Double(duration) - resume <= Self.completionRemainingThreshold {
            return nil
        }
        return resume
    }

    public var publishedDate: Date? {
        guard let published else { return nil }
        if let date = isoFormatter.date(from: published) {
            return date
        }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        return dateOnly.date(from: published)
    }

    public var publishedFormatted: String? {
        guard let date = publishedDate else { return nil }
        return displayFormatter.string(from: date)
    }

    public var publishedRelative: String? {
        guard let date = publishedDate else { return nil }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    public var formattedViewCount: String? {
        guard let count = stats?.viewCount else { return nil }
        return count.formatted(.number.notation(.compactName))
    }

    public var formattedLikeCount: String? {
        guard let count = stats?.likeCount else { return nil }
        return count.formatted(.number.notation(.compactName))
    }

    public var formattedDislikeCount: String? {
        guard let count = stats?.dislikeCount else { return nil }
        return count.formatted(.number.notation(.compactName))
    }

    public var formattedFileSize: String? {
        guard let mediaSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(mediaSize))
    }

    public var resolution: String? {
        guard let videoStream = streams?.first(where: { $0.type == "video" }),
              let width = videoStream.width,
              let height = videoStream.height else { return nil }
        return "\(width)x\(height)"
    }

    public var qualityLabel: String? {
        guard let videoStream = streams?.first(where: { $0.type == "video" }),
              let height = videoStream.height else { return nil }
        return switch height {
        case 2160...: "4K"
        case 1440...: "UHD"
        case 720...: "HD"
        default: "SD"
        }
    }

    public var videoCodec: String? {
        guard let codec = streams?.first(where: { $0.type == "video" })?.codec else { return nil }
        return codec.uppercased()
    }

    public var audioCodec: String? {
        guard let codec = streams?.first(where: { $0.type == "audio" })?.codec else { return nil }
        return codec.uppercased()
    }

    public var linkedDescription: AttributedString? {
        guard let description, !description.isEmpty else { return nil }
        var result = AttributedString(description)
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return result }
        let nsString = description as NSString
        let matches = detector.matches(
            in: description,
            range: NSRange(location: 0, length: nsString.length)
        )
        for match in matches {
            guard let url = match.url,
                  let range = Range(match.range, in: description)
            else { continue }
            let start = result.index(
                result.startIndex,
                offsetByCharacters: description.distance(
                    from: description.startIndex,
                    to: range.lowerBound
                )
            )
            let end = result.index(
                start,
                offsetByCharacters: description.distance(
                    from: range.lowerBound,
                    to: range.upperBound
                )
            )
            result[start..<end].link = url
        }
        return result
    }

    public var isoFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    public var displayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    public var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    public init(
        videoId: String,
        title: String,
        description: String?,
        category: [String]?,
        channel: VideoChannel,
        published: String?,
        dateDownloaded: Int?,
        vidLastRefresh: String?,
        vidThumbUrl: String?,
        vidType: VideoType?,
        active: Bool?,
        mediaUrl: String?,
        mediaSize: Int?,
        player: VideoPlayer?,
        stats: VideoStats?,
        subtitles: [VideoSubtitle]?,
        streams: [VideoStream]?,
        tags: [String]?,
        commentCount: Int?
    ) {
        self.videoId = videoId
        self.title = title
        self.description = description
        self.category = category
        self.channel = channel
        self.published = published
        self.dateDownloaded = dateDownloaded
        self.vidLastRefresh = vidLastRefresh
        self.vidThumbUrl = vidThumbUrl
        self.vidType = vidType
        self.active = active
        self.mediaUrl = mediaUrl
        self.mediaSize = mediaSize
        self.player = player
        self.stats = stats
        self.subtitles = subtitles
        self.streams = streams
        self.tags = tags
        self.commentCount = commentCount
    }

    public static let placeholder = VideoResponse(
        videoId: "placeholder",
        title: "Placeholder Video Title Here",
        description: nil,
        category: nil,
        channel: .placeholder,
        published: "2025-01-01T00:00:00+00:00",
        dateDownloaded: nil,
        vidLastRefresh: nil,
        vidThumbUrl: nil,
        vidType: nil,
        active: nil,
        mediaUrl: nil,
        mediaSize: nil,
        player: VideoPlayer(
            watched: false,
            watchedDate: nil,
            duration: 754,
            durationStr: "12m 34s",
            progress: nil,
            position: nil
        ),
        stats: nil,
        subtitles: nil,
        streams: nil,
        tags: nil,
        commentCount: nil
    )

    public static let placeholders: IdentifiedArrayOf<VideoResponse> = {
        var items = IdentifiedArrayOf<VideoResponse>()
        for index in 0..<20 {
            let video = VideoResponse(
                videoId: "placeholder-\(index)",
                title: placeholder.title,
                description: nil,
                category: nil,
                channel: .placeholder,
                published: placeholder.published,
                dateDownloaded: nil,
                vidLastRefresh: nil,
                vidThumbUrl: nil,
                vidType: nil,
                active: nil,
                mediaUrl: nil,
                mediaSize: nil,
                player: placeholder.player,
                stats: nil,
                subtitles: nil,
                streams: nil,
                tags: nil,
                commentCount: nil
            )
            items.append(video)
        }
        return items
    }()

    enum CodingKeys: String, CodingKey {
        case videoId = "youtube_id"
        case title
        case description
        case category
        case channel
        case published
        case dateDownloaded = "date_downloaded"
        case vidLastRefresh = "vid_last_refresh"
        case vidThumbUrl = "vid_thumb_url"
        case vidType = "vid_type"
        case active
        case mediaUrl = "media_url"
        case mediaSize = "media_size"
        case player
        case stats
        case subtitles
        case streams
        case tags
        case commentCount = "comment_count"
    }
}

public nonisolated struct VideoChannel: Decodable, Sendable, Equatable {
    public let channelId: String
    public let channelName: String
    public let channelActive: Bool?
    public let channelBannerUrl: String?
    public let channelThumbUrl: String?
    public let channelTvartUrl: String?
    public let channelDescription: String?
    public let channelLastRefresh: String?
    public let channelSubs: Int?
    public let channelSubscribed: Bool?
    public let channelTags: [String]?
    public let channelTabs: [String]?

    public init(
        channelId: String,
        channelName: String,
        channelActive: Bool?,
        channelBannerUrl: String?,
        channelThumbUrl: String?,
        channelTvartUrl: String?,
        channelDescription: String?,
        channelLastRefresh: String?,
        channelSubs: Int?,
        channelSubscribed: Bool?,
        channelTags: [String]?,
        channelTabs: [String]?
    ) {
        self.channelId = channelId
        self.channelName = channelName
        self.channelActive = channelActive
        self.channelBannerUrl = channelBannerUrl
        self.channelThumbUrl = channelThumbUrl
        self.channelTvartUrl = channelTvartUrl
        self.channelDescription = channelDescription
        self.channelLastRefresh = channelLastRefresh
        self.channelSubs = channelSubs
        self.channelSubscribed = channelSubscribed
        self.channelTags = channelTags
        self.channelTabs = channelTabs
    }

    public static let placeholder = VideoChannel(
        channelId: "placeholder-channel",
        channelName: "Channel Name",
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
    )

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case channelName = "channel_name"
        case channelActive = "channel_active"
        case channelBannerUrl = "channel_banner_url"
        case channelThumbUrl = "channel_thumb_url"
        case channelTvartUrl = "channel_tvart_url"
        case channelDescription = "channel_description"
        case channelLastRefresh = "channel_last_refresh"
        case channelSubs = "channel_subs"
        case channelSubscribed = "channel_subscribed"
        case channelTags = "channel_tags"
        case channelTabs = "channel_tabs"
    }
}

public nonisolated enum VideoType: String, Decodable, Sendable, Equatable {
    case videos
    case streams
    case shorts
    case unknown
}

public nonisolated struct VideoPlayer: Decodable, Sendable, Equatable {
    public let watched: Bool?
    public let watchedDate: Int?
    public let duration: Int?
    public let durationStr: String?
    public let progress: Double?
    public let position: Double?

    public init(
        watched: Bool?, watchedDate: Int?, duration: Int?,
        durationStr: String?, progress: Double?, position: Double?
    ) {
        self.watched = watched
        self.watchedDate = watchedDate
        self.duration = duration
        self.durationStr = durationStr
        self.progress = progress
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case watched
        case watchedDate = "watched_date"
        case duration
        case durationStr = "duration_str"
        case progress
        case position
    }
}

public nonisolated struct VideoStats: Decodable, Sendable, Equatable {
    public let viewCount: Int?
    public let likeCount: Int?
    public let dislikeCount: Int?
    public let averageRating: Double?

    public init(
        viewCount: Int?,
        likeCount: Int?,
        dislikeCount: Int?,
        averageRating: Double?
    ) {
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.averageRating = averageRating
    }

    enum CodingKeys: String, CodingKey {
        case viewCount = "view_count"
        case likeCount = "like_count"
        case dislikeCount = "dislike_count"
        case averageRating = "average_rating"
    }
}

public nonisolated struct VideoSubtitle: Decodable, Sendable, Equatable {
    public let ext: String?
    public let url: String?
    public let name: String?
    public let lang: String?
    public let source: String?
    public let mediaUrl: String?

    public init(
        ext: String?,
        url: String?,
        name: String?,
        lang: String?,
        source: String?,
        mediaUrl: String?
    ) {
        self.ext = ext
        self.url = url
        self.name = name
        self.lang = lang
        self.source = source
        self.mediaUrl = mediaUrl
    }

    enum CodingKeys: String, CodingKey {
        case ext
        case url
        case name
        case lang
        case source
        case mediaUrl = "media_url"
    }
}

public nonisolated struct VideoStream: Decodable, Sendable, Equatable {
    public let type: String?
    public let index: Int?
    public let codec: String?
    public let width: Int?
    public let height: Int?
    public let bitrate: Int?

    public init(
        type: String?,
        index: Int?,
        codec: String?,
        width: Int?,
        height: Int?,
        bitrate: Int?
    ) {
        self.type = type
        self.index = index
        self.codec = codec
        self.width = width
        self.height = height
        self.bitrate = bitrate
    }

    enum CodingKeys: String, CodingKey {
        case type
        case index
        case codec
        case width
        case height
        case bitrate
    }
}
