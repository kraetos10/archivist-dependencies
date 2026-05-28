import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SearchService: Sendable {
    public var search: @Sendable (
        _ config: ServerConfig,
        _ query: String
    ) async throws -> SearchResponse
}

extension SearchService: DependencyKey {
    public static let liveValue = SearchService(
        search: { config, query in
            let queryItems = [URLQueryItem(name: "query", value: query)]
            let request = NetworkAPIRequest<SearchResponseWrapper>(
                config: config,
                path: .search,
                queryItems: queryItems
            )
            return try await request.execute().data.results
        }
    )

    public static var testValue: SearchService { SearchService() }
}
