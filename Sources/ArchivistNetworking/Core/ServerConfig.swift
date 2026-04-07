import Foundation

public nonisolated struct ServerConfig: Sendable, Codable, Equatable {
    public let baseURL: String
    public let port: Int?
    public let apiToken: String
    public let useHTTP: Bool

    public init(
        baseURL: String,
        port: Int? = nil,
        apiToken: String,
        useHTTP: Bool = false
    ) {
        self.baseURL = baseURL
        self.port = port
        self.apiToken = apiToken
        self.useHTTP = useHTTP
    }

    public var scheme: String {
        useHTTP ? "http" : "https"
    }

    public var hostname: String {
        if let components = URLComponents(string: baseURL), let host = components.host {
            return host
        }
        return baseURL
    }

    public var authHeaders: [String: String] {
        ["Authorization": "Token \(apiToken)"]
    }

    public func fullURL(for relativePath: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = hostname
        components.port = port
        components.path = relativePath.hasPrefix("/") ? relativePath : "/\(relativePath)"
        return components.url
    }
}
