import Dependencies
import Foundation

public protocol HealthServiceType: Sendable {
    func checkHealth(baseURL: String, port: Int?, useHTTP: Bool) async throws
}

public struct HealthService: HealthServiceType {
    public init() {}

    public func checkHealth(baseURL: String, port: Int?, useHTTP: Bool) async throws {
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
}
