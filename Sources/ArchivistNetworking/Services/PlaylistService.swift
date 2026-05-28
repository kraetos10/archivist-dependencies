import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct PlaylistService: Sendable {
    public var getPlaylists: @Sendable (
        _ config: ServerConfig,
        _ page: Int,
        _ type: String?,
        _ channel: String?,
        _ subscribed: Bool?
    ) async throws -> PaginatedResponse<PlaylistResponse>
    public var getPlaylist: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> PlaylistResponse
    public var subscribePlaylists: @Sendable (
        _ config: ServerConfig,
        _ items: [PlaylistSubscribeItem]
    ) async throws -> Void
    public var updatePlaylist: @Sendable (
        _ config: ServerConfig,
        _ id: String,
        _ subscribed: Bool
    ) async throws -> Void
    public var deletePlaylist: @Sendable (
        _ config: ServerConfig,
        _ id: String,
        _ deleteVideos: Bool
    ) async throws -> Void
    public var createCustomPlaylist: @Sendable (
        _ config: ServerConfig,
        _ name: String
    ) async throws -> Void
    public var modifyCustomPlaylist: @Sendable (
        _ config: ServerConfig,
        _ id: String,
        _ action: String,
        _ videoId: String?,
        _ position: Int?
    ) async throws -> Void
}

extension PlaylistService {
    public func modifyCustomPlaylist(
        config: ServerConfig,
        id: String,
        action: String,
        videoId: String?
    ) async throws {
        try await modifyCustomPlaylist(config: config, id: id, action: action, videoId: videoId, position: nil)
    }
}

extension PlaylistService: DependencyKey {
    public static let liveValue = PlaylistService(
        getPlaylists: { config, page, type, channel, subscribed in
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
        },
        getPlaylist: { config, id in
            let request = NetworkAPIRequest<PlaylistResponse>(
                config: config,
                path: .playlist(id: id)
            )
            return try await request.execute().data
        },
        subscribePlaylists: { config, items in
            let body = try JSONEncoder().encode(PlaylistSubscribeRequest(data: items))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .playlistList,
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        updatePlaylist: { config, id, subscribed in
            let body = try JSONEncoder().encode(["playlist_subscribed": subscribed])
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .playlist(id: id),
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        deletePlaylist: { config, id, deleteVideos in
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
        },
        createCustomPlaylist: { config, name in
            let body = try JSONEncoder().encode(["playlist_name": name])
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .playlistCustom,
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        modifyCustomPlaylist: { config, id, action, videoId, position in
            let body = try JSONEncoder().encode(CustomPlaylistRequest(action: action, videoId: videoId, position: position))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .playlistCustomAction(id: id),
                method: .post,
                body: body
            )
            _ = try await request.execute()
        }
    )

    public static var testValue: PlaylistService { PlaylistService() }
}
