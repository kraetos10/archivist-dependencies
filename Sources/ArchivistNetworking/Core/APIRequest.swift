import Dependencies
import Foundation

public nonisolated protocol APIRequest: Sendable {
    associatedtype DecodableData

    var method: HTTPMethod { get }
    var path: String { get }
    var queryItems: [URLQueryItem]? { get }
    var headers: [HTTPHeader] { get }
    var body: Data? { get }

    func urlRequest() throws -> URLRequest
    func execute() async throws -> (data: DecodableData, headers: [AnyHashable: Any])
}

public nonisolated struct NetworkAPIRequest<T: Decodable>: APIRequest {
    public let method: HTTPMethod
    public let path: String
    public let queryItems: [URLQueryItem]?
    public let headers: [HTTPHeader]
    public let body: Data?
    public let config: ServerConfig

    private let jsonDecoder: JSONDecoder

    public typealias DecodableData = T

    public init(
        config: ServerConfig,
        path: Paths,
        queryItems: [URLQueryItem]? = nil,
        method: HTTPMethod = .get,
        body: Data? = nil,
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) {
        self.config = config
        self.path = path.rawValue
        self.queryItems = queryItems
        self.method = method
        self.body = body
        self.jsonDecoder = jsonDecoder

        var httpHeaders = config.authHeaders
            .sorted { $0.key < $1.key }
            .map { HTTPHeader(field: $0.key, value: $0.value) }
        httpHeaders.append(HTTPHeader(field: "Content-Type", value: "application/json"))
        self.headers = httpHeaders
    }

    /// An unauthenticated request against a server address that hasn't been
    /// turned into a full `ServerConfig` yet (the token request). It is
    /// resolved through the same `ServerConfig` URL builder as everything else.
    public init(
        useHTTP: Bool = false,
        baseURL: String,
        path: Paths,
        queryItems: [URLQueryItem]? = nil,
        method: HTTPMethod = .get,
        body: Data? = nil,
        port: Int? = nil,
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(
            config: ServerConfig(
                baseURL: baseURL,
                port: port,
                apiToken: "",
                useHTTP: useHTTP
            ),
            path: path,
            queryItems: queryItems,
            method: method,
            body: body,
            jsonDecoder: jsonDecoder
        )
    }

    public func urlRequest() throws -> URLRequest {
        guard let url = config.url(path: path, queryItems: queryItems) else {
            throw NetworkingError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body
        for header in headers {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.field)
        }
        return urlRequest
    }

    public func execute() async throws -> (data: DecodableData, headers: [AnyHashable: Any]) {
        @Dependency(\.urlSession) var urlSession
        let request = try urlRequest()

        let (data, response) = try await urlSession.data(for: request)
        var responseHeaders = [AnyHashable: Any]()

        if let response = response as? HTTPURLResponse {
            guard (200..<300).contains(response.statusCode) else {
                let error = NetworkingError(
                    statusCode: response.statusCode,
                    body: data
                )
                if error.isInvalidToken {
                    @Dependency(\.authEventService) var authEventService
                    await authEventService.tokenExpired()
                }
                throw error
            }
            responseHeaders = response.allHeaderFields
        }

        let decodeData = data.isEmpty ? Data("{}".utf8) : data
        do {
            let decoded = try jsonDecoder.decode(DecodableData.self, from: decodeData)
            return (data: decoded, headers: responseHeaders)
        } catch let error as DecodingError {
            throw NetworkingError.decodingFailed(String(describing: error))
        }
    }
}
