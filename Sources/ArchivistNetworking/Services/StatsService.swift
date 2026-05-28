import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct StatsService: Sendable {
    public var getVideoStats: @Sendable (_ config: ServerConfig) async throws -> VideoStatsResponse
    public var getChannelStats: @Sendable (_ config: ServerConfig) async throws -> ChannelStatsResponse
    public var getPlaylistStats: @Sendable (_ config: ServerConfig) async throws -> PlaylistStatsResponse
    public var getDownloadStats: @Sendable (_ config: ServerConfig) async throws -> DownloadStatsResponse
    public var getWatchStats: @Sendable (_ config: ServerConfig) async throws -> WatchStatsResponse
    public var getBiggestChannels: @Sendable (_ config: ServerConfig) async throws -> [BiggestChannelResponse]
    public var getDownloadHistory: @Sendable (_ config: ServerConfig) async throws -> [DownloadHistResponse]
}

extension StatsService: DependencyKey {
    public static let liveValue = StatsService(
        getVideoStats: { config in
            let request = NetworkAPIRequest<VideoStatsResponse>(config: config, path: .statsVideo)
            return try await request.execute().data
        },
        getChannelStats: { config in
            let request = NetworkAPIRequest<ChannelStatsResponse>(config: config, path: .statsChannel)
            return try await request.execute().data
        },
        getPlaylistStats: { config in
            let request = NetworkAPIRequest<PlaylistStatsResponse>(config: config, path: .statsPlaylist)
            return try await request.execute().data
        },
        getDownloadStats: { config in
            let request = NetworkAPIRequest<DownloadStatsResponse>(config: config, path: .statsDownload)
            return try await request.execute().data
        },
        getWatchStats: { config in
            let request = NetworkAPIRequest<WatchStatsResponse>(config: config, path: .statsWatch)
            return try await request.execute().data
        },
        getBiggestChannels: { config in
            let request = NetworkAPIRequest<[BiggestChannelResponse]>(config: config, path: .statsBiggestChannels)
            return try await request.execute().data
        },
        getDownloadHistory: { config in
            let request = NetworkAPIRequest<[DownloadHistResponse]>(config: config, path: .statsDownloadHist)
            return try await request.execute().data
        }
    )

    public static var testValue: StatsService { StatsService() }
}
