import Foundation

public nonisolated protocol StatsServiceType: Sendable {
    func getVideoStats(config: ServerConfig) async throws -> VideoStatsResponse
    func getChannelStats(config: ServerConfig) async throws -> ChannelStatsResponse
    func getPlaylistStats(config: ServerConfig) async throws -> PlaylistStatsResponse
    func getDownloadStats(config: ServerConfig) async throws -> DownloadStatsResponse
    func getWatchStats(config: ServerConfig) async throws -> WatchStatsResponse
    func getBiggestChannels(config: ServerConfig) async throws -> [BiggestChannelResponse]
    func getDownloadHistory(config: ServerConfig) async throws -> [DownloadHistResponse]
}

public nonisolated struct StatsService: StatsServiceType {
    public init() {}

    public func getVideoStats(config: ServerConfig) async throws -> VideoStatsResponse {
        let request = NetworkAPIRequest<VideoStatsResponse>(config: config, path: .statsVideo)
        return try await request.execute().data
    }

    public func getChannelStats(config: ServerConfig) async throws -> ChannelStatsResponse {
        let request = NetworkAPIRequest<ChannelStatsResponse>(config: config, path: .statsChannel)
        return try await request.execute().data
    }

    public func getPlaylistStats(config: ServerConfig) async throws -> PlaylistStatsResponse {
        let request = NetworkAPIRequest<PlaylistStatsResponse>(config: config, path: .statsPlaylist)
        return try await request.execute().data
    }

    public func getDownloadStats(config: ServerConfig) async throws -> DownloadStatsResponse {
        let request = NetworkAPIRequest<DownloadStatsResponse>(config: config, path: .statsDownload)
        return try await request.execute().data
    }

    public func getWatchStats(config: ServerConfig) async throws -> WatchStatsResponse {
        let request = NetworkAPIRequest<WatchStatsResponse>(config: config, path: .statsWatch)
        return try await request.execute().data
    }

    public func getBiggestChannels(config: ServerConfig) async throws -> [BiggestChannelResponse] {
        let request = NetworkAPIRequest<[BiggestChannelResponse]>(config: config, path: .statsBiggestChannels)
        return try await request.execute().data
    }

    public func getDownloadHistory(config: ServerConfig) async throws -> [DownloadHistResponse] {
        let request = NetworkAPIRequest<[DownloadHistResponse]>(config: config, path: .statsDownloadHist)
        return try await request.execute().data
    }
}
