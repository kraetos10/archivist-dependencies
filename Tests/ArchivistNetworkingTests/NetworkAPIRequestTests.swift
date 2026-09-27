@testable import ArchivistNetworking
import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@Suite(.serialized, .timeLimit(.minutes(1)))
struct NetworkAPIRequestTests {
    let config = ServerConfig(
        baseURL: "https://example.com/ta",
        port: 8443,
        apiToken: "secret"
    )

    @Test func requestCarriesPrefixQueryAndHeaders() throws {
        let request = try NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .videoList,
            queryItems: [URLQueryItem(name: "page", value: "2")],
            method: .post,
            body: Data("{}".utf8)
        )
        .urlRequest()

        #expect(request.url?.absoluteString == "https://example.com:8443/ta/api/video/?page=2")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Token secret")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody == Data("{}".utf8))
    }

    @Test func tokenRequestHasNoAuthorizationHeader() throws {
        let request = try NetworkAPIRequest<TokenResponse>(
            useHTTP: true,
            baseURL: "http://nas.local:8000/",
            path: .token
        )
        .urlRequest()

        #expect(request.url?.absoluteString == "http://nas.local:8000/api/appsettings/token/")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func invalidAddressThrowsInvalidURL() {
        let config = ServerConfig(baseURL: "", apiToken: "x")
        #expect(throws: NetworkingError.invalidURL) {
            try NetworkAPIRequest<EmptyResponse>(config: config, path: .ping).urlRequest()
        }
    }

    @Test func decodesASuccessfulResponse() async throws {
        let session = StubURLProtocol.session { _ in
            .init(statusCode: 200, body: Data(#"{"response":"pong","user":3,"version":"v0.5"}"#.utf8))
        }
        let ping = try await withDependencies {
            $0.urlSession = session
        } operation: {
            try await NetworkAPIRequest<PingResponse>(config: config, path: .ping).execute().data
        }
        #expect(ping == PingResponse(response: "pong", user: 3, version: "v0.5"))
        #expect(StubURLProtocol.requests.value.first?.url?.absoluteString == "https://example.com:8443/ta/api/ping/")
    }

    @Test func anEmptyBodyDecodesAsEmptyResponse() async throws {
        let session = StubURLProtocol.session { _ in .init(statusCode: 204) }
        try await withDependencies {
            $0.urlSession = session
        } operation: {
            _ = try await NetworkAPIRequest<EmptyResponse>(config: config, path: .watched, method: .post).execute()
        }
    }

    @Test func aServerErrorKeepsTheStatusAndBody() async {
        let session = StubURLProtocol.session { _ in .init(statusCode: 500, body: Data("boom".utf8)) }
        await #expect(throws: NetworkingError.errorStatusCode(500, "boom")) {
            try await withDependencies {
                $0.urlSession = session
            } operation: {
                try await NetworkAPIRequest<PingResponse>(config: config, path: .ping).execute()
            }
        }
    }

    @Test func aMismatchedBodyIsADecodingFailure() async {
        let session = StubURLProtocol.session { _ in .init(statusCode: 200, body: Data(#"{"data": 1}"#.utf8)) }
        await #expect {
            try await withDependencies {
                $0.urlSession = session
            } operation: {
                try await NetworkAPIRequest<PaginatedResponse<VideoResponse>>(
                    config: config,
                    path: .videoList
                )
                .execute()
            }
        } throws: { error in
            guard case .decodingFailed = error as? NetworkingError else { return false }
            return true
        }
    }

    @Test func anInvalidTokenEndsTheSession() async throws {
        let session = StubURLProtocol.session { _ in
            .init(statusCode: 403, body: Data(#"{"detail":"Invalid token."}"#.utf8))
        }
        let authEvents = AuthEventService.testValue
        await #expect(throws: NetworkingError.self) {
            try await withDependencies {
                $0.urlSession = session
                $0.authEventService = authEvents
            } operation: {
                try await NetworkAPIRequest<PingResponse>(config: config, path: .ping).execute()
            }
        }
        var iterator = await authEvents.subscribe().makeAsyncIterator()
        #expect(await iterator.next() == true)
    }

    @Test func aPermissionErrorDoesNotEndTheSession() async throws {
        let session = StubURLProtocol.session { _ in
            .init(statusCode: 403, body: Data(#"{"detail":"You do not have permission."}"#.utf8))
        }
        let authEvents = AuthEventService.testValue
        await #expect(throws: NetworkingError.self) {
            try await withDependencies {
                $0.urlSession = session
                $0.authEventService = authEvents
            } operation: {
                try await NetworkAPIRequest<PingResponse>(config: config, path: .ping).execute()
            }
        }
        var iterator = await authEvents.subscribe().makeAsyncIterator()
        #expect(await iterator.next() == false)
    }

    @Test func healthCheckUsesTheSameURLBuilder() async throws {
        let session = StubURLProtocol.session { _ in .init(statusCode: 200) }
        try await withDependencies {
            $0.urlSession = session
        } operation: {
            try await HealthService.liveValue.checkHealth(
                baseURL: " https://example.com/ta ",
                port: nil,
                useHTTP: false
            )
        }
        #expect(StubURLProtocol.requests.value.first?.url?.absoluteString == "https://example.com/ta/api/health/")
    }

    @Test func healthCheckSurfacesAFailingStatus() async {
        let session = StubURLProtocol.session { _ in .init(statusCode: 502) }
        await #expect(throws: NetworkingError.errorStatusCode(502, "")) {
            try await withDependencies {
                $0.urlSession = session
            } operation: {
                try await HealthService.liveValue.checkHealth(baseURL: "example.com", port: nil, useHTTP: false)
            }
        }
    }
}
