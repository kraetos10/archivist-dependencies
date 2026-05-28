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

            var components = URLComponents()
            components.scheme = useHTTP ? "http" : "https"
            components.host = baseURL
            components.port = port
            components.path = "/api/health/"

            guard let url = components.url else {
                throw NetworkingError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let (_, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw NetworkingError.errorStatusCode(statusCode, "")
            }
        }
    )

    public static var testValue: HealthService { HealthService() }
}
