#if !os(tvOS)
import ArchivistNetworking
import Dependencies
import Foundation

/// Loads CarPlay's lists. Each list stops at `limit` items — CarPlay can't
/// show more than its template allows, and paging a whole library over a
/// car's connection before showing anything left the lists empty for ages.
@MainActor
public final class CarPlayDataProvider {
    public let serverConfig: ServerConfig

    @Dependency(\.channelService) private var channelService
    @Dependency(\.playlistService) private var playlistService
    @Dependency(\.videoService) private var videoService

    public init(serverConfig: ServerConfig) {
        self.serverConfig = serverConfig
    }

    public func fetchRecentVideos(
        sort: VideoSortOrder = .published,
        limit: Int
    ) async throws -> [VideoResponse] {
        let config = serverConfig
        return try await Self.collect(limit: limit) { [videoService] page in
            try await videoService.getVideos(
                config: config,
                page: page,
                sort: sort.apiValue,
                order: "desc",
                type: nil,
                watch: "unwatched",
                channel: nil,
                playlist: nil
            )
        }
    }

    public func fetchChannels(limit: Int) async throws -> [ChannelResponse] {
        let config = serverConfig
        return try await Self.collect(limit: limit) { [channelService] page in
            try await channelService.getChannels(
                config: config,
                page: page,
                filter: nil,
                query: nil
            )
        }
    }

    public func fetchPlaylists(limit: Int) async throws -> [PlaylistResponse] {
        let config = serverConfig
        return try await Self.collect(limit: limit) { [playlistService] page in
            try await playlistService.getPlaylists(
                config: config,
                page: page,
                type: nil,
                channel: nil,
                subscribed: nil
            )
        }
    }

    public func fetchChannelVideos(
        channelId: String,
        limit: Int
    ) async throws -> [VideoResponse] {
        let config = serverConfig
        return try await Self.collect(limit: limit) { [videoService] page in
            try await videoService.getVideos(
                config: config,
                page: page,
                sort: nil,
                order: nil,
                type: nil,
                watch: nil,
                channel: channelId,
                playlist: nil
            )
        }
    }

    public func fetchPlaylistVideos(
        playlistId: String,
        limit: Int
    ) async throws -> [VideoResponse] {
        let config = serverConfig
        return try await Self.collect(limit: limit) { [videoService] page in
            try await videoService.getVideos(
                config: config,
                page: page,
                sort: nil,
                order: nil,
                type: nil,
                watch: nil,
                channel: nil,
                playlist: playlistId
            )
        }
    }

    public func buildMediaURL(for video: VideoResponse) -> URL? {
        guard let mediaPath = video.mediaUrl else { return nil }
        return serverConfig.fullURL(for: mediaPath)
    }

    public func buildThumbnailURL(for path: String?) -> URL? {
        guard let path else { return nil }
        return serverConfig.fullURL(for: path)
    }

    /// Pages until `limit` items are in hand or the server runs out.
    private static func collect<Item: Decodable & Sendable>(
        limit: Int,
        fetchPage: @Sendable (Int) async throws -> PaginatedResponse<Item>
    ) async throws -> [Item] {
        var items: [Item] = []
        var page = 1
        while items.count < limit {
            try Task.checkCancellation()
            let response = try await fetchPage(page)
            items.append(contentsOf: response.data)
            if page >= response.paginate.lastPage { break }
            page += 1
        }
        return Array(items.prefix(limit))
    }
}
#endif
