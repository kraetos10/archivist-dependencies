import Dependencies
import Foundation

/// Answers every request from `handler` instead of the network. Suites using
/// it are `.serialized`, since the handler is shared.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        var statusCode = 200
        var body = Data()
    }

    static let handler = LockIsolated<@Sendable (URLRequest) -> Response>({ _ in Response() })
    static let requests = LockIsolated<[URLRequest]>([])

    static func session(_ respond: @escaping @Sendable (URLRequest) -> Response) -> URLSession {
        handler.setValue(respond)
        requests.setValue([])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.withValue { $0.append(request) }
        let response = Self.handler.value(request)
        guard let url = request.url,
              let http = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: nil
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
