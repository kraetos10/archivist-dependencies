import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct HealthService: Sendable {
    public var checkHealth: @Sendable (
        _ baseURL: String,
        _ port: Int?,
        _ useHTTP: Bool
    ) async throws -> Void
}

extension HealthService: DependencyKey {
    public static let liveValue = HealthService(
        checkHealth: { baseURL, port, useHTTP in
            @Dependency(\.urlSession) var urlSession

            // Through the same builder as authenticated requests, so an
            // address with a scheme, port or subpath resolves identically.
            let config = ServerConfig(
                baseURL: baseURL,
                port: port,
                apiToken: "",
                useHTTP: useHTTP
            )
            guard let url = config.url(path: Paths.health.rawValue) else {
                throw NetworkingError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = HTTPMethod.get.rawValue

            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkingError.missingData
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw NetworkingError(statusCode: httpResponse.statusCode, body: data)
            }
        }
    )

    public static var testValue: HealthService { HealthService() }
    public static var previewValue: HealthService {
        HealthService(checkHealth: { _, _, _ in })
    }
}
