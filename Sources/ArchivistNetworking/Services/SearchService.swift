import Foundation

public nonisolated protocol SearchServiceType: Sendable {
    func search(config: ServerConfig, query: String) async throws -> SearchResponse
}

public nonisolated struct SearchService: SearchServiceType {
    public init() {}

    public func search(config: ServerConfig, query: String) async throws -> SearchResponse {
        let queryItems = [URLQueryItem(name: "query", value: query)]
        let request = NetworkAPIRequest<SearchResponseWrapper>(
            config: config,
            path: .search,
            queryItems: queryItems
        )
        return try await request.execute().data.results
    }
}
