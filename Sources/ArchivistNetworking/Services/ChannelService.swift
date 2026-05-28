import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct ChannelService: Sendable {
    public var getChannels: @Sendable (
        _ config: ServerConfig,
        _ page: Int,
        _ filter: String?,
        _ query: String?
    ) async throws -> PaginatedResponse<ChannelResponse>
    public var getChannel: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> ChannelResponse
    public var subscribeChannels: @Sendable (
        _ config: ServerConfig,
        _ items: [ChannelSubscribeItem]
    ) async throws -> Void
    public var updateChannel: @Sendable (
        _ config: ServerConfig,
        _ id: String,
        _ update: ChannelUpdateRequest
    ) async throws -> Void
    public var deleteChannel: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> Void
    public var getChannelAggs: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> ChannelAggsResponse
    public var getChannelNav: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> ChannelNavResponse
    public var searchChannel: @Sendable (
        _ config: ServerConfig,
        _ query: String
    ) async throws -> [ChannelResponse]
}

extension ChannelService: DependencyKey {
    public static let liveValue = ChannelService(
        getChannels: { config, page, filter, query in
            var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
            if let filter { queryItems.append(URLQueryItem(name: "filter", value: filter)) }
            if let query { queryItems.append(URLQueryItem(name: "q", value: query)) }

            let request = NetworkAPIRequest<PaginatedResponse<ChannelResponse>>(
                config: config,
                path: .channelList,
                queryItems: queryItems
            )
            return try await request.execute().data
        },
        getChannel: { config, id in
            let request = NetworkAPIRequest<ChannelResponse>(
                config: config,
                path: .channel(id: id)
            )
            return try await request.execute().data
        },
        subscribeChannels: { config, items in
            let body = try JSONEncoder().encode(ChannelSubscribeRequest(data: items))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .channelList,
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        updateChannel: { config, id, update in
            let body = try JSONEncoder().encode(update)
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .channel(id: id),
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        deleteChannel: { config, id in
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .channel(id: id),
                method: .delete
            )
            _ = try await request.execute()
        },
        getChannelAggs: { config, id in
            let request = NetworkAPIRequest<ChannelAggsResponse>(
                config: config,
                path: .channelAggs(id: id)
            )
            return try await request.execute().data
        },
        getChannelNav: { config, id in
            let request = NetworkAPIRequest<ChannelNavResponse>(
                config: config,
                path: .channelNav(id: id)
            )
            return try await request.execute().data
        },
        searchChannel: { config, query in
            let queryItems = [URLQueryItem(name: "q", value: query)]
            let request = NetworkAPIRequest<[ChannelResponse]>(
                config: config,
                path: .channelSearch,
                queryItems: queryItems
            )
            return try await request.execute().data
        }
    )

    public static var testValue: ChannelService { ChannelService() }
}
