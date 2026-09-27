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

    /// The scheme is decided by the "use HTTP" setting, not by anything typed
    /// into the address field, so a stray `https://` can't override it.
    public var scheme: String {
        useHTTP ? "http" : "https"
    }

    /// The server address with any scheme, port, path and whitespace stripped.
    public var hostname: String {
        endpoint.host
    }

    /// The port to connect on: the explicit port setting wins, then a port
    /// typed into the address (`host:8000`).
    public var resolvedPort: Int? {
        endpoint.port
    }

    /// Any path the address carries (`https://example.com/tubearchivist`),
    /// without a trailing slash. A server behind a reverse proxy on a subpath
    /// needs it in front of every API and media path.
    public var pathPrefix: String {
        endpoint.pathPrefix
    }

    public var authHeaders: [String: String] {
        apiToken.isEmpty ? [:] : ["Authorization": "Token \(apiToken)"]
    }

    /// Thumbnail URL for a video, preferring the copy cached on disk
    /// alongside a device download so artwork still resolves when the
    /// server is unreachable.
    public func thumbnailURL(
        videoId: String,
        path: String?
    ) -> URL? {
        if let localURL = LocalVideoStorage.localThumbnailURL(for: videoId) {
            return localURL
        }
        guard let path, !path.isEmpty else { return nil }
        return fullURL(for: path)
    }

    /// Absolute URL for a server-relative path such as a thumbnail or media
    /// path. A path that is already an absolute URL is returned unchanged.
    public func fullURL(for relativePath: String) -> URL? {
        if relativePath.contains("://") {
            return URL(string: relativePath)
        }
        return url(path: relativePath)
    }

    /// Builds a URL on this server from its scheme, host, port and path
    /// prefix. API requests, the health check, the token request and media
    /// URLs all come through here, so they agree on what the address means.
    public func url(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) -> URL? {
        let endpoint = endpoint
        guard !endpoint.host.isEmpty else { return nil }
        let relative = path.hasPrefix("/") ? path : "/\(path)"
        var components = URLComponents()
        components.scheme = scheme
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = endpoint.pathPrefix + relative
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }

    /// True when `url` points at this server, so it may carry the auth header.
    /// An exact host match: a lookalike host must never receive the token.
    public func isServerURL(_ url: URL) -> Bool {
        guard let host = url.host, !hostname.isEmpty else { return false }
        return host.caseInsensitiveCompare(hostname) == .orderedSame
    }

    private var endpoint: ServerEndpoint {
        ServerEndpoint(
            address: baseURL,
            explicitPort: port,
            scheme: scheme
        )
    }
}

private nonisolated struct ServerEndpoint {
    let host: String
    let port: Int?
    let pathPrefix: String

    init(
        address: String,
        explicitPort: Int?,
        scheme: String
    ) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.contains("://") ? trimmed : "\(scheme)://\(trimmed)"
        guard let components = URLComponents(string: withScheme),
              let host = components.host,
              !host.isEmpty else {
            self.host = trimmed
            self.port = explicitPort
            self.pathPrefix = ""
            return
        }
        self.host = host
        self.port = explicitPort ?? components.port
        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        self.pathPrefix = path
    }
}
