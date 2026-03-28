import Foundation

public nonisolated struct LoginRequest: Encodable, Sendable {
    public let username: String
    public let password: String
    public let rememberMe: String?

    public init(
        username: String,
        password: String,
        rememberMe: String?
    ) {
        self.username = username
        self.password = password
        self.rememberMe = rememberMe
    }

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case rememberMe = "remember_me"
    }
}

public nonisolated struct AddDownloadRequest: Encodable, Sendable {
    public let data: [AddDownloadItem]

    public init(data: [AddDownloadItem]) {
        self.data = data
    }
}

public nonisolated struct AddDownloadItem: Encodable, Sendable {
    public let youtubeId: String
    public let status: String

    public init(
        youtubeId: String,
        status: String
    ) {
        self.youtubeId = youtubeId
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case youtubeId = "youtube_id"
        case status
    }
}

public nonisolated struct BulkDownloadUpdateRequest: Encodable, Sendable {
    public let videoIds: [String]
    public let status: String

    public init(
        videoIds: [String],
        status: String
    ) {
        self.videoIds = videoIds
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case videoIds = "video_ids"
        case status
    }
}

public nonisolated struct ChannelSubscribeRequest: Encodable, Sendable {
    public let data: [ChannelSubscribeItem]

    public init(data: [ChannelSubscribeItem]) {
        self.data = data
    }
}

public nonisolated struct ChannelSubscribeItem: Encodable, Sendable {
    public let channelId: String
    public let channelSubscribed: Bool

    public init(
        channelId: String,
        channelSubscribed: Bool
    ) {
        self.channelId = channelId
        self.channelSubscribed = channelSubscribed
    }

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case channelSubscribed = "channel_subscribed"
    }
}

public nonisolated struct ChannelUpdateRequest: Encodable, Sendable {
    public let channelSubscribed: Bool?
    public let channelOverwrites: ChannelOverwritesRequest?

    public init(
        channelSubscribed: Bool?,
        channelOverwrites: ChannelOverwritesRequest?
    ) {
        self.channelSubscribed = channelSubscribed
        self.channelOverwrites = channelOverwrites
    }

    enum CodingKeys: String, CodingKey {
        case channelSubscribed = "channel_subscribed"
        case channelOverwrites = "channel_overwrites"
    }
}

public nonisolated struct ChannelOverwritesRequest: Encodable, Sendable {
    public let downloadFormat: String?
    public let autodelete: Int?
    public let indexPlaylists: Bool?
    public let integrateSponsorblock: Bool?

    public init(
        downloadFormat: String?,
        autodelete: Int?,
        indexPlaylists: Bool?,
        integrateSponsorblock: Bool?
    ) {
        self.downloadFormat = downloadFormat
        self.autodelete = autodelete
        self.indexPlaylists = indexPlaylists
        self.integrateSponsorblock = integrateSponsorblock
    }

    enum CodingKeys: String, CodingKey {
        case downloadFormat = "download_format"
        case autodelete
        case indexPlaylists = "index_playlists"
        case integrateSponsorblock = "integrate_sponsorblock"
    }
}

public nonisolated struct PlaylistSubscribeRequest: Encodable, Sendable {
    public let data: [PlaylistSubscribeItem]

    public init(data: [PlaylistSubscribeItem]) {
        self.data = data
    }
}

public nonisolated struct PlaylistSubscribeItem: Encodable, Sendable {
    public let playlistId: String
    public let playlistSubscribed: Bool

    public init(
        playlistId: String,
        playlistSubscribed: Bool
    ) {
        self.playlistId = playlistId
        self.playlistSubscribed = playlistSubscribed
    }

    enum CodingKeys: String, CodingKey {
        case playlistId = "playlist_id"
        case playlistSubscribed = "playlist_subscribed"
    }
}

public nonisolated struct CustomPlaylistRequest: Encodable, Sendable {
    public let action: String
    public let videoId: String?
    public let position: Int?

    public init(
        action: String,
        videoId: String?,
        position: Int? = nil
    ) {
        self.action = action
        self.videoId = videoId
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case action
        case videoId = "video_id"
        case position
    }
}

public nonisolated struct VideoProgressRequest: Encodable, Sendable {
    public let position: Int

    public init(position: Int) {
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case position
    }
}

public nonisolated struct WatchedRequest: Encodable, Sendable {
    public let id: String
    public let isWatched: Bool

    public init(
        id: String,
        isWatched: Bool
    ) {
        self.id = id
        self.isWatched = isWatched
    }

    enum CodingKeys: String, CodingKey {
        case id
        case isWatched = "is_watched"
    }
}

public nonisolated struct RefreshRequest: Encodable, Sendable {
    public let id: String?
    public let type: String?
    public let extractVideos: Bool?

    public init(
        id: String?,
        type: String?,
        extractVideos: Bool?
    ) {
        self.id = id
        self.type = type
        self.extractVideos = extractVideos
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case extractVideos = "extract_videos"
    }
}

public nonisolated struct TaskCommandRequest: Encodable, Sendable {
    public let command: String

    public init(command: String) {
        self.command = command
    }
}

public nonisolated struct TaskScheduleRequest: Encodable, Sendable {
    public let schedule: String?
    public let config: [String: String]?

    public init(
        schedule: String?,
        config: [String: String]?
    ) {
        self.schedule = schedule
        self.config = config
    }
}
