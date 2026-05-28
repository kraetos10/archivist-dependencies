import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct UserService: Sendable {
    public var getToken: @Sendable (
        _ baseURL: String,
        _ port: Int?,
        _ useHTTP: Bool
    ) async throws -> TokenResponse
    public var getAccount: @Sendable (
        _ config: ServerConfig
    ) async throws -> UserAccountResponse
    public var getUserConfig: @Sendable (
        _ config: ServerConfig
    ) async throws -> UserConfigResponse
    public var updateUserConfig: @Sendable (
        _ config: ServerConfig,
        _ updates: [String: String]
    ) async throws -> Void
}

extension UserService: DependencyKey {
    public static let liveValue = UserService(
        getToken: { baseURL, port, useHTTP in
            let request = NetworkAPIRequest<TokenResponse>(
                useHTTP: useHTTP,
                baseURL: baseURL,
                path: .token,
                port: port
            )
            return try await request.execute().data
        },
        getAccount: { config in
            let request = NetworkAPIRequest<UserAccountResponse>(config: config, path: .userAccount)
            return try await request.execute().data
        },
        getUserConfig: { config in
            let request = NetworkAPIRequest<UserConfigResponse>(config: config, path: .userMe)
            return try await request.execute().data
        },
        updateUserConfig: { config, updates in
            let body = try JSONEncoder().encode(updates)
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .userMe,
                method: .post,
                body: body
            )
            _ = try await request.execute()
        }
    )

    public static var testValue: UserService { UserService() }
}
