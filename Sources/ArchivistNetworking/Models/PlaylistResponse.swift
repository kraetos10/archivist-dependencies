import Foundation
import IdentifiedCollections

public nonisolated struct PlaylistResponse: Decodable, Sendable, Equatable, Identifiable {
    public let playlistId: String
    public let playlistName: String
    public let playlistType: PlaylistType
    public let playlistChannelId: String?
    public let playlistChannel: String?
    public let playlistDescription: String?
    public let playlistThumbnail: String?
    public let playlistSubscribed: Bool
    public let playlistActive: Bool
    public let playlistSortOrder: String?
    public let playlistLastRefresh: String?
    public let playlistEntries: [PlaylistEntry]?

    public var id: String { playlistId }

    public var youtubeURL: URL {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistId)")!
    }

    public var entryCount: Int {
        playlistEntries?.count ?? 0
    }

    public func withEntries(_ entries: [PlaylistEntry]) -> PlaylistResponse {
        PlaylistResponse(
            playlistId: playlistId,
            playlistName: playlistName,
            playlistType: playlistType,
            playlistChannelId: playlistChannelId,
            playlistChannel: playlistChannel,
            playlistDescription: playlistDescription,
            playlistThumbnail: playlistThumbnail,
            playlistSubscribed: playlistSubscribed,
            playlistActive: playlistActive,
            playlistSortOrder: playlistSortOrder,
            playlistLastRefresh: playlistLastRefresh,
            playlistEntries: entries
        )
    }

    public func thumbURL(config: ServerConfig) -> URL? {
        guard let path = playlistThumbnail else { return nil }
        return config.fullURL(for: path)
    }

    public init(
        playlistId: String,
        playlistName: String,
        playlistType: PlaylistType,
        playlistChannelId: String?,
        playlistChannel: String?,
        playlistDescription: String?,
        playlistThumbnail: String?,
        playlistSubscribed: Bool,
        playlistActive: Bool,
        playlistSortOrder: String?,
        playlistLastRefresh: String?,
        playlistEntries: [PlaylistEntry]?
    ) {
        self.playlistId = playlistId
        self.playlistName = playlistName
        self.playlistType = playlistType
        self.playlistChannelId = playlistChannelId
        self.playlistChannel = playlistChannel
        self.playlistDescription = playlistDescription
        self.playlistThumbnail = playlistThumbnail
        self.playlistSubscribed = playlistSubscribed
        self.playlistActive = playlistActive
        self.playlistSortOrder = playlistSortOrder
        self.playlistLastRefresh = playlistLastRefresh
        self.playlistEntries = playlistEntries
    }

    public static let placeholder = PlaylistResponse(
        playlistId: "placeholder",
        playlistName: "Playlist Name Placeholder",
        playlistType: .regular,
        playlistChannelId: nil,
        playlistChannel: "Channel Name",
        playlistDescription: nil,
        playlistThumbnail: nil,
        playlistSubscribed: true,
        playlistActive: true,
        playlistSortOrder: nil,
        playlistLastRefresh: nil,
        playlistEntries: nil
    )

    public static let placeholders: IdentifiedArrayOf<PlaylistResponse> = {
        var items = IdentifiedArrayOf<PlaylistResponse>()
        for i in 0..<6 {
            let p = PlaylistResponse(
                playlistId: "placeholder-\(i)",
                playlistName: placeholder.playlistName,
                playlistType: .regular,
                playlistChannelId: nil,
                playlistChannel: placeholder.playlistChannel,
                playlistDescription: nil,
                playlistThumbnail: nil,
                playlistSubscribed: true,
                playlistActive: true,
                playlistSortOrder: nil,
                playlistLastRefresh: nil,
                playlistEntries: nil
            )
            items.append(p)
        }
        return items
    }()

    enum CodingKeys: String, CodingKey {
        case playlistId = "playlist_id"
        case playlistName = "playlist_name"
        case playlistType = "playlist_type"
        case playlistChannelId = "playlist_channel_id"
        case playlistChannel = "playlist_channel"
        case playlistDescription = "playlist_description"
        case playlistThumbnail = "playlist_thumbnail"
        case playlistSubscribed = "playlist_subscribed"
        case playlistActive = "playlist_active"
        case playlistSortOrder = "playlist_sort_order"
        case playlistLastRefresh = "playlist_last_refresh"
        case playlistEntries = "playlist_entries"
    }
}

public nonisolated enum PlaylistType: String, Decodable, Sendable, Equatable {
    case regular
    case custom
}

public nonisolated struct PlaylistEntry: Decodable, Sendable, Equatable, Identifiable {
    public let youtubeId: String?
    public let title: String?
    public let idx: Int?
    public let uploader: String?
    public let vidThumbUrl: String?

    public var id: String { youtubeId ?? "\(idx ?? 0)" }

    public func thumbURL(config: ServerConfig) -> URL? {
        if let path = vidThumbUrl {
            return config.fullURL(for: path)
        }
        guard let videoId = youtubeId else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg")
    }

    public init(
        youtubeId: String?,
        title: String?,
        idx: Int?,
        uploader: String?,
        vidThumbUrl: String?
    ) {
        self.youtubeId = youtubeId
        self.title = title
        self.idx = idx
        self.uploader = uploader
        self.vidThumbUrl = vidThumbUrl
    }

    enum CodingKeys: String, CodingKey {
        case youtubeId = "youtube_id"
        case title
        case idx
        case uploader
        case vidThumbUrl = "vid_thumb_url"
    }
}
