import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct PingService: Sendable {
    public var ping: @Sendable (_ config: ServerConfig) async throws -> PingResponse
}

extension PingService: DependencyKey {
    public static let liveValue = PingService(
        ping: { config in
            let request = NetworkAPIRequest<PingResponse>(config: config, path: .ping)
            return try await request.execute().data
        }
    )

    public static var testValue: PingService { PingService() }
}
