import Foundation

public nonisolated protocol UserServiceType: Sendable {
    func login(
        baseURL: String,
        port: Int?,
        useHTTP: Bool,
        username: String,
        password: String
    ) async throws
    func getToken(
        baseURL: String,
        port: Int?,
        useHTTP: Bool
    ) async throws -> TokenResponse
    func logout(config: ServerConfig) async throws
    func getAccount(config: ServerConfig) async throws -> UserAccountResponse
    func getUserConfig(config: ServerConfig) async throws -> UserConfigResponse
    func updateUserConfig(
        config: ServerConfig,
        updates: [String: String]
    ) async throws
}

public nonisolated struct UserService: UserServiceType {
    public init() {}

    public func login(
        baseURL: String,
        port: Int? = nil,
        useHTTP: Bool = false,
        username: String,
        password: String
    ) async throws {
        let body = try JSONEncoder().encode(
            LoginRequest(username: username, password: password, rememberMe: nil)
        )
        let request = NetworkAPIRequest<EmptyResponse>(
            useHTTP: useHTTP,
            baseURL: baseURL,
            path: .userLogin,
            method: .post,
            body: body,
            port: port
        )
        _ = try await request.execute()
    }

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

    public func logout(config: ServerConfig) async throws {
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .userLogout,
            method: .post
        )
        _ = try await request.execute()
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
