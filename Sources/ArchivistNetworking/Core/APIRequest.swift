import Dependencies
import Foundation

public nonisolated protocol APIRequest {
    var method: HTTPMethod { get }
    var path: String? { get }
    var queryItems: [URLQueryItem]? { get }
    var headers: [HTTPHeader]? { get }
    var body: Data? { get }
    var baseURL: String { get }
    var port: Int? { get }

    associatedtype DecodableData

    func urlRequest() throws -> URLRequest
    func execute() async throws -> (data: DecodableData, headers: [AnyHashable: Any])
}

public nonisolated final class NetworkAPIRequest<T: Decodable>: APIRequest, @unchecked Sendable {
    public let method: HTTPMethod
    public let path: String?
    public var queryItems: [URLQueryItem]?
    public let headers: [HTTPHeader]?
    public var body: Data?
    public let baseURL: String
    public let port: Int?
    public let scheme: String

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
        self.scheme = config.scheme
        self.baseURL = config.hostname
        self.path = path.rawValue
        self.queryItems = queryItems
        self.method = method
        self.body = body
        self.port = config.port
        self.jsonDecoder = jsonDecoder

        var httpHeaders = config.authHeaders.map { HTTPHeader(field: $0.key, value: $0.value) }
        httpHeaders.append(HTTPHeader(field: "Content-Type", value: "application/json"))
        self.headers = httpHeaders
    }

    public init(
        useHTTP: Bool = false,
        baseURL: String,
        path: Paths,
        queryItems: [URLQueryItem]? = nil,
        method: HTTPMethod = .get,
        body: Data? = nil,
        port: Int? = nil,
        headers: [String: String] = [:],
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) {
        self.scheme = useHTTP ? "http" : "https"
        self.baseURL = baseURL
        self.path = path.rawValue
        self.queryItems = queryItems
        self.method = method
        self.body = body
        self.port = port
        self.jsonDecoder = jsonDecoder

        var httpHeaders = headers.map { HTTPHeader(field: $0.key, value: $0.value) }
        if !headers.keys.contains("Content-Type") {
            httpHeaders.append(HTTPHeader(field: "Content-Type", value: "application/json"))
        }
        self.headers = httpHeaders
    }

    public func urlRequest() throws -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = baseURL
        urlComponents.port = port
        urlComponents.path = path ?? ""
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw NetworkingError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body

        headers?.forEach { urlRequest.addValue($0.value, forHTTPHeaderField: $0.field) }

        return urlRequest
    }

    public func execute() async throws -> (data: DecodableData, headers: [AnyHashable: Any]) {
        @Dependency(\.urlSession) var urlSession
        var request = try urlRequest()

        if method != .get, let url = request.url,
           let csrfToken = HTTPCookieStorage.shared.cookies(for: url)?
            .first(where: { $0.name == "csrftoken" })?.value {
            request.addValue(csrfToken, forHTTPHeaderField: "X-CSRFToken")
        }

        let (data, response) = try await urlSession.data(for: request)
        var responseHeaders = [AnyHashable: Any]()

        if let response = response as? HTTPURLResponse {
            guard response.statusCode >= 200 && response.statusCode < 300 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                let error = NetworkingError.errorStatusCode(response.statusCode, body)

                if response.statusCode == 403, body.contains("Invalid token") {
                    Task { @MainActor in
                        NotificationCenter.default.post(name: .authTokenExpired, object: nil)
                    }
                }

                throw error
            }
            responseHeaders = response.allHeaderFields
        }

        let decodeData = data.isEmpty ? Data("{}".utf8) : data
        let decoded = try jsonDecoder.decode(DecodableData.self, from: decodeData)
        return (data: decoded, headers: responseHeaders)
    }
}
