import Foundation

public nonisolated protocol UserServiceType: Sendable {
    func getToken(
        baseURL: String,
        port: Int?,
        useHTTP: Bool
    ) async throws -> TokenResponse
    func getAccount(config: ServerConfig) async throws -> UserAccountResponse
    func getUserConfig(config: ServerConfig) async throws -> UserConfigResponse
    func updateUserConfig(
        config: ServerConfig,
        updates: [String: String]
    ) async throws
}

public nonisolated struct UserService: UserServiceType {
    public init() {}

    public func getToken(
        baseURL: String,
        port: Int? = nil,
        useHTTP: Bool = false
    ) async throws -> TokenResponse {
        let request = NetworkAPIRequest<TokenResponse>(
            useHTTP: useHTTP,
            baseURL: baseURL,
            path: .token,
            port: port
        )
        return try await request.execute().data
    }

    public func getAccount(config: ServerConfig) async throws -> UserAccountResponse {
        let request = NetworkAPIRequest<UserAccountResponse>(config: config, path: .userAccount)
        return try await request.execute().data
    }

    public func getUserConfig(config: ServerConfig) async throws -> UserConfigResponse {
        let request = NetworkAPIRequest<UserConfigResponse>(config: config, path: .userMe)
        return try await request.execute().data
    }

    public func updateUserConfig(
        config: ServerConfig,
        updates: [String: String]
    ) async throws {
        let body = try JSONEncoder().encode(updates)
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .userMe,
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }
}
