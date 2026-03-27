import Foundation

public nonisolated protocol PlaylistServiceType: Sendable {
    func getPlaylists(config: ServerConfig, page: Int, type: String?, channel: String?, subscribed: Bool?) async throws -> PaginatedResponse<PlaylistResponse>
    func getPlaylist(config: ServerConfig, id: String) async throws -> PlaylistResponse
    func subscribePlaylists(config: ServerConfig, items: [PlaylistSubscribeItem]) async throws
    func updatePlaylist(config: ServerConfig, id: String, subscribed: Bool) async throws
    func deletePlaylist(config: ServerConfig, id: String, deleteVideos: Bool) async throws
    func createCustomPlaylist(config: ServerConfig, name: String) async throws
    func modifyCustomPlaylist(config: ServerConfig, id: String, action: String, videoId: String?, position: Int?) async throws
}

extension PlaylistServiceType {
    public func modifyCustomPlaylist(config: ServerConfig, id: String, action: String, videoId: String?) async throws {
        try await modifyCustomPlaylist(config: config, id: id, action: action, videoId: videoId, position: nil)
    }
}

public nonisolated struct PlaylistService: PlaylistServiceType {
    public init() {}

    public func getPlaylists(
        config: ServerConfig,
        page: Int = 1,
        type: String? = nil,
        channel: String? = nil,
        subscribed: Bool? = nil
    ) async throws -> PaginatedResponse<PlaylistResponse> {
        var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
        if let type { queryItems.append(URLQueryItem(name: "type", value: type)) }
        if let channel { queryItems.append(URLQueryItem(name: "channel", value: channel)) }
        if let subscribed { queryItems.append(URLQueryItem(name: "subscribed", value: "\(subscribed)")) }

        let request = NetworkAPIRequest<PaginatedResponse<PlaylistResponse>>(
            config: config,
            path: .playlistList,
            queryItems: queryItems
        )
        return try await request.execute().data
    }

    public func getPlaylist(config: ServerConfig, id: String) async throws -> PlaylistResponse {
        let request = NetworkAPIRequest<PlaylistResponse>(
            config: config,
            path: .playlist(id: id)
        )
        return try await request.execute().data
    }

    public func subscribePlaylists(config: ServerConfig, items: [PlaylistSubscribeItem]) async throws {
        let body = try JSONEncoder().encode(PlaylistSubscribeRequest(data: items))
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .playlistList,
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func updatePlaylist(config: ServerConfig, id: String, subscribed: Bool) async throws {
        let body = try JSONEncoder().encode(["playlist_subscribed": subscribed])
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .playlist(id: id),
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func deletePlaylist(config: ServerConfig, id: String, deleteVideos: Bool = false) async throws {
        var queryItems: [URLQueryItem]?
        if deleteVideos {
            queryItems = [URLQueryItem(name: "delete_videos", value: "true")]
        }
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .playlist(id: id),
            queryItems: queryItems,
            method: .delete
        )
        _ = try await request.execute()
    }

    public func createCustomPlaylist(config: ServerConfig, name: String) async throws {
        let body = try JSONEncoder().encode(["playlist_name": name])
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .playlistCustom,
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func modifyCustomPlaylist(config: ServerConfig, id: String, action: String, videoId: String?, position: Int? = nil) async throws {
        let body = try JSONEncoder().encode(CustomPlaylistRequest(action: action, videoId: videoId, position: position))
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .playlistCustomAction(id: id),
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }
}
