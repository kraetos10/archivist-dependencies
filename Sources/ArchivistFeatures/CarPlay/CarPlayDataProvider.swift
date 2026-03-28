#if !os(tvOS)
import ArchivistNetworking
import Foundation

@MainActor
public final class CarPlayDataProvider {
    public let serverConfig: ServerConfig

    private let videoService = VideoService()
    private let channelService = ChannelService()
    private let playlistService = PlaylistService()

    public init(serverConfig: ServerConfig) {
        self.serverConfig = serverConfig
    }

    public func fetchRecentVideos(sort: VideoSortOrder = .published) async throws -> [VideoResponse] {
        var allVideos: [VideoResponse] = []
        var page = 1
        while true {
            let response = try await videoService.getVideos(
                config: serverConfig,
                page: page,
                sort: sort.apiValue,
                order: "desc",
                type: nil,
                watch: "unwatched",
                channel: nil,
                playlist: nil
            )
            allVideos.append(contentsOf: response.data)
            if page >= response.paginate.lastPage { break }
            page += 1
        }
        return allVideos
    }

    public func fetchChannels() async throws -> [ChannelResponse] {
        var allChannels: [ChannelResponse] = []
        var page = 1
        while true {
            let response = try await channelService.getChannels(
                config: serverConfig,
                page: page,
                filter: nil,
                query: nil
            )
            allChannels.append(contentsOf: response.data)
            if page >= response.paginate.lastPage { break }
            page += 1
        }
        return allChannels
    }

    public func fetchPlaylists() async throws -> [PlaylistResponse] {
        var allPlaylists: [PlaylistResponse] = []
        var page = 1
        while true {
            let response = try await playlistService.getPlaylists(
                config: serverConfig,
                page: page,
                type: nil,
                channel: nil,
                subscribed: nil
            )
            allPlaylists.append(contentsOf: response.data)
            if page >= response.paginate.lastPage { break }
            page += 1
        }
        return allPlaylists
    }

    public func fetchChannelVideos(channelId: String) async throws -> [VideoResponse] {
        var allVideos: [VideoResponse] = []
        var page = 1
        while true {
            let response = try await videoService.getVideos(
                config: serverConfig,
                page: page,
                sort: nil,
                order: nil,
                type: nil,
                watch: nil,
                channel: channelId,
                playlist: nil
            )
            allVideos.append(contentsOf: response.data)
            if page >= response.paginate.lastPage { break }
            page += 1
        }
        return allVideos
    }

    public func fetchPlaylistVideos(playlistId: String) async throws -> [VideoResponse] {
        var allVideos: [VideoResponse] = []
        var page = 1
        while true {
            let response = try await videoService.getVideos(
                config: serverConfig,
                page: page,
                sort: nil,
                order: nil,
                type: nil,
                watch: nil,
                channel: nil,
                playlist: playlistId
            )
            allVideos.append(contentsOf: response.data)
            if page >= response.paginate.lastPage { break }
            page += 1
        }
        return allVideos
    }

    public func buildMediaURL(for video: VideoResponse) -> URL? {
        guard let mediaPath = video.mediaUrl else { return nil }
        return serverConfig.fullURL(for: mediaPath)
    }

    public func buildThumbnailURL(for path: String?) -> URL? {
        guard let path else { return nil }
        return serverConfig.fullURL(for: path)
    }
}
#endif
