import Foundation

public nonisolated protocol ChannelServiceType: Sendable {
    func getChannels(config: ServerConfig, page: Int, filter: String?, query: String?) async throws -> PaginatedResponse<ChannelResponse>
    func getChannel(config: ServerConfig, id: String) async throws -> ChannelResponse
    func subscribeChannels(config: ServerConfig, items: [ChannelSubscribeItem]) async throws
    func updateChannel(config: ServerConfig, id: String, update: ChannelUpdateRequest) async throws
    func deleteChannel(config: ServerConfig, id: String) async throws
    func getChannelAggs(config: ServerConfig, id: String) async throws -> ChannelAggsResponse
    func getChannelNav(config: ServerConfig, id: String) async throws -> ChannelNavResponse
    func searchChannel(config: ServerConfig, query: String) async throws -> [ChannelResponse]
}

public nonisolated struct ChannelService: ChannelServiceType {
    public init() {}

    public func getChannels(
        config: ServerConfig,
        page: Int = 1,
        filter: String? = nil,
        query: String? = nil
    ) async throws -> PaginatedResponse<ChannelResponse> {
        var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
        if let filter { queryItems.append(URLQueryItem(name: "filter", value: filter)) }
        if let query { queryItems.append(URLQueryItem(name: "q", value: query)) }

        let request = NetworkAPIRequest<PaginatedResponse<ChannelResponse>>(
            config: config,
            path: .channelList,
            queryItems: queryItems
        )
        return try await request.execute().data
    }

    public func getChannel(config: ServerConfig, id: String) async throws -> ChannelResponse {
        let request = NetworkAPIRequest<ChannelResponse>(
            config: config,
            path: .channel(id: id)
        )
        return try await request.execute().data
    }

    public func subscribeChannels(config: ServerConfig, items: [ChannelSubscribeItem]) async throws {
        let body = try JSONEncoder().encode(ChannelSubscribeRequest(data: items))
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .channelList,
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func updateChannel(config: ServerConfig, id: String, update: ChannelUpdateRequest) async throws {
        let body = try JSONEncoder().encode(update)
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .channel(id: id),
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func deleteChannel(config: ServerConfig, id: String) async throws {
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .channel(id: id),
            method: .delete
        )
        _ = try await request.execute()
    }

    public func getChannelAggs(config: ServerConfig, id: String) async throws -> ChannelAggsResponse {
        let request = NetworkAPIRequest<ChannelAggsResponse>(
            config: config,
            path: .channelAggs(id: id)
        )
        return try await request.execute().data
    }

    public func getChannelNav(config: ServerConfig, id: String) async throws -> ChannelNavResponse {
        let request = NetworkAPIRequest<ChannelNavResponse>(
            config: config,
            path: .channelNav(id: id)
        )
        return try await request.execute().data
    }

    public func searchChannel(config: ServerConfig, query: String) async throws -> [ChannelResponse] {
        let queryItems = [URLQueryItem(name: "q", value: query)]
        let request = NetworkAPIRequest<[ChannelResponse]>(
            config: config,
            path: .channelSearch,
            queryItems: queryItems
        )
        return try await request.execute().data
    }
}
