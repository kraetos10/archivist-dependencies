import Foundation
import IdentifiedCollections

public nonisolated struct ChannelResponse: Decodable, Sendable, Equatable, Identifiable, Hashable {
    public let channelId: String
    public let channelName: String
    public let channelDescription: String?
    public let channelSubs: Int?
    public let channelActive: Bool
    public let channelSubscribed: Bool
    public let channelTags: [String]?
    public let channelTabs: [String]?
    public let channelOverwrites: ChannelOverwrites?
    public let channelLastRefresh: String?
    public let channelBannerUrl: String?
    public let channelThumbUrl: String?
    public let channelTvartUrl: String?

    public var id: String { channelId }

    public var youtubeURL: URL? {
        URL(string: "https://www.youtube.com/channel/\(channelId)")
    }

    public var formattedSubs: String? {
        guard let subs = channelSubs else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .halfUp
        let number = Double(subs)
        switch number {
        case 1_000_000_000...:
            formatter.positiveSuffix = "B"
            return formatter.string(from: NSNumber(value: number / 1_000_000_000))
        case 1_000_000...:
            formatter.positiveSuffix = "M"
            return formatter.string(from: NSNumber(value: number / 1_000_000))
        case 1_000...:
            formatter.positiveSuffix = "K"
            return formatter.string(from: NSNumber(value: number / 1_000))
        default:
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: subs))
        }
    }

    public static let placeholder = ChannelResponse(
        channelId: "placeholder",
        channelName: "Channel Name Placeholder",
        channelDescription: nil,
        channelSubs: 12345,
        channelActive: true,
        channelSubscribed: true,
        channelTags: nil,
        channelTabs: nil,
        channelOverwrites: nil,
        channelLastRefresh: nil,
        channelBannerUrl: nil,
        channelThumbUrl: nil,
        channelTvartUrl: nil
    )

    public static let placeholders: IdentifiedArrayOf<ChannelResponse> = {
        var items = IdentifiedArrayOf<ChannelResponse>()
        for index in 0..<8 {
            let channel = ChannelResponse(
                channelId: "placeholder-\(index)",
                channelName: placeholder.channelName,
                channelDescription: nil,
                channelSubs: placeholder.channelSubs,
                channelActive: true,
                channelSubscribed: true,
                channelTags: nil,
                channelTabs: nil,
                channelOverwrites: nil,
                channelLastRefresh: nil,
                channelBannerUrl: nil,
                channelThumbUrl: nil,
                channelTvartUrl: nil
            )
            items.append(channel)
        }
        return items
    }()

    public init(
        channelId: String,
        channelName: String,
        channelDescription: String?,
        channelSubs: Int?,
        channelActive: Bool,
        channelSubscribed: Bool,
        channelTags: [String]?,
        channelTabs: [String]?,
        channelOverwrites: ChannelOverwrites?,
        channelLastRefresh: String?,
        channelBannerUrl: String?,
        channelThumbUrl: String?,
        channelTvartUrl: String?
    ) {
        self.channelId = channelId
        self.channelName = channelName
        self.channelDescription = channelDescription
        self.channelSubs = channelSubs
        self.channelActive = channelActive
        self.channelSubscribed = channelSubscribed
        self.channelTags = channelTags
        self.channelTabs = channelTabs
        self.channelOverwrites = channelOverwrites
        self.channelLastRefresh = channelLastRefresh
        self.channelBannerUrl = channelBannerUrl
        self.channelThumbUrl = channelThumbUrl
        self.channelTvartUrl = channelTvartUrl
    }

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case channelName = "channel_name"
        case channelDescription = "channel_description"
        case channelSubs = "channel_subs"
        case channelActive = "channel_active"
        case channelSubscribed = "channel_subscribed"
        case channelTags = "channel_tags"
        case channelTabs = "channel_tabs"
        case channelOverwrites = "channel_overwrites"
        case channelLastRefresh = "channel_last_refresh"
        case channelBannerUrl = "channel_banner_url"
        case channelThumbUrl = "channel_thumb_url"
        case channelTvartUrl = "channel_tvart_url"
    }
}

public nonisolated struct ChannelOverwrites: Decodable, Sendable, Equatable, Hashable {
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

public nonisolated struct ChannelAggsResponse: Decodable, Sendable, Equatable {
    public let totalItems: Int?
    public let totalDuration: Int?
    public let totalSize: Int?

    public init(
        totalItems: Int?,
        totalDuration: Int?,
        totalSize: Int?
    ) {
        self.totalItems = totalItems
        self.totalDuration = totalDuration
        self.totalSize = totalSize
    }

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case totalDuration = "total_duration"
        case totalSize = "total_size"
    }
}

public nonisolated struct ChannelNavResponse: Decodable, Sendable, Equatable {
    public let channels: [ChannelNavItem]?

    public init(channels: [ChannelNavItem]?) {
        self.channels = channels
    }
}

public nonisolated struct ChannelNavItem: Decodable, Sendable, Equatable {
    public let channelId: String?
    public let channelName: String?

    public init(
        channelId: String?,
        channelName: String?
    ) {
        self.channelId = channelId
        self.channelName = channelName
    }

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case channelName = "channel_name"
    }
}
