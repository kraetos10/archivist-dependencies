import Foundation
import IdentifiedCollections

public nonisolated struct DownloadResponse: Decodable, Sendable, Equatable, Identifiable {
    public let youtubeId: String
    public let title: String?
    public let channelId: String
    public let channelName: String?
    public let channelIndexed: Bool?
    public let status: DownloadStatus
    public let vidType: VideoType
    public let duration: String?
    public let published: String?
    public let timestamp: Int?
    public let vidThumbUrl: String?
    public let message: String?

    public var id: String { youtubeId }

    public var publishedRelative: String? {
        guard let published else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: published) else { return nil }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        return relative.localizedString(for: date, relativeTo: Date())
    }

    public var youtubeURL: URL {
        URL(string: "https://www.youtube.com/watch?v=\(youtubeId)")!
    }

    public func thumbURL(config: ServerConfig) -> URL? {
        guard let path = vidThumbUrl else { return nil }
        return config.fullURL(for: path)
    }

    public init(
        youtubeId: String,
        title: String?,
        channelId: String,
        channelName: String?,
        channelIndexed: Bool?,
        status: DownloadStatus,
        vidType: VideoType,
        duration: String?,
        published: String?,
        timestamp: Int?,
        vidThumbUrl: String?,
        message: String?
    ) {
        self.youtubeId = youtubeId
        self.title = title
        self.channelId = channelId
        self.channelName = channelName
        self.channelIndexed = channelIndexed
        self.status = status
        self.vidType = vidType
        self.duration = duration
        self.published = published
        self.timestamp = timestamp
        self.vidThumbUrl = vidThumbUrl
        self.message = message
    }

    public static let placeholder = DownloadResponse(
        youtubeId: "placeholder",
        title: "Placeholder Download Title",
        channelId: "placeholder-channel",
        channelName: "Channel Name",
        channelIndexed: nil,
        status: .pending,
        vidType: .videos,
        duration: "12:34",
        published: nil,
        timestamp: nil,
        vidThumbUrl: nil,
        message: nil
    )

    public static let placeholders: IdentifiedArrayOf<DownloadResponse> = {
        var items = IdentifiedArrayOf<DownloadResponse>()
        for index in 0..<6 {
            let download = DownloadResponse(
                youtubeId: "placeholder-\(index)",
                title: placeholder.title,
                channelId: placeholder.channelId,
                channelName: placeholder.channelName,
                channelIndexed: nil,
                status: .pending,
                vidType: .videos,
                duration: placeholder.duration,
                published: nil,
                timestamp: nil,
                vidThumbUrl: nil,
                message: nil
            )
            items.append(download)
        }
        return items
    }()

    enum CodingKeys: String, CodingKey {
        case youtubeId = "youtube_id"
        case title
        case channelId = "channel_id"
        case channelName = "channel_name"
        case channelIndexed = "channel_indexed"
        case status
        case vidType = "vid_type"
        case duration
        case published
        case timestamp
        case vidThumbUrl = "vid_thumb_url"
        case message
    }
}

public nonisolated enum DownloadStatus: String, Decodable, Sendable, Equatable {
    case pending
    case ignore
    case priority
}

public nonisolated struct DownloadAggsResponse: Decodable, Sendable, Equatable {
    public let pending: Int?
    public let ignore: Int?
    public let pendingVideos: Int?
    public let pendingShorts: Int?
    public let pendingStreams: Int?

    public init(
        pending: Int?,
        ignore: Int?,
        pendingVideos: Int?,
        pendingShorts: Int?,
        pendingStreams: Int?
    ) {
        self.pending = pending
        self.ignore = ignore
        self.pendingVideos = pendingVideos
        self.pendingShorts = pendingShorts
        self.pendingStreams = pendingStreams
    }

    enum CodingKeys: String, CodingKey {
        case pending
        case ignore
        case pendingVideos = "pending_videos"
        case pendingShorts = "pending_shorts"
        case pendingStreams = "pending_streams"
    }
}
