import Foundation

public protocol PingServiceType: Sendable {
    func ping(config: ServerConfig) async throws -> PingResponse
}

public struct PingService: PingServiceType {
    public init() {}

    public func ping(config: ServerConfig) async throws -> PingResponse {
        let request = NetworkAPIRequest<PingResponse>(config: config, path: .ping)
        return try await request.execute().data
    }
}
