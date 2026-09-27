import ArchivistNetworking
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ServerConfigTests {
    private func config(
        _ address: String,
        port: Int? = nil,
        useHTTP: Bool = false,
        token: String = "abc"
    ) -> ServerConfig {
        ServerConfig(
            baseURL: address,
            port: port,
            apiToken: token,
            useHTTP: useHTTP
        )
    }

    @Test func bareHostBuildsAnHTTPSURL() {
        #expect(
            config("tube.example.com").url(path: "/api/ping/")?.absoluteString
                == "https://tube.example.com/api/ping/"
        )
    }

    @Test func useHTTPPicksTheScheme() {
        #expect(
            config("tube.example.com", useHTTP: true).url(path: "/api/ping/")?.absoluteString
                == "http://tube.example.com/api/ping/"
        )
    }

    @Test func aTypedSchemeIsStrippedAndTheSettingWins() {
        let config = config("https://tube.example.com", useHTTP: true)
        #expect(config.hostname == "tube.example.com")
        #expect(config.url(path: "/api/ping/")?.absoluteString == "http://tube.example.com/api/ping/")
    }

    @Test func surroundingWhitespaceIsIgnored() {
        #expect(
            config("  tube.example.com \n").url(path: "/api/ping/")?.absoluteString
                == "https://tube.example.com/api/ping/"
        )
    }

    @Test func aSubpathIsKeptInFrontOfEveryPath() {
        let config = config("https://example.com/tubearchivist/")
        #expect(config.pathPrefix == "/tubearchivist")
        #expect(config.url(path: "/api/video/")?.absoluteString == "https://example.com/tubearchivist/api/video/")
        #expect(
            config.fullURL(for: "cache/videos/a/b.jpg")?.absoluteString
                == "https://example.com/tubearchivist/cache/videos/a/b.jpg"
        )
    }

    @Test func aPortTypedIntoTheAddressIsUsed() {
        let config = config("192.168.1.10:8000", useHTTP: true)
        #expect(config.hostname == "192.168.1.10")
        #expect(config.resolvedPort == 8000)
        #expect(config.url(path: "/api/ping/")?.absoluteString == "http://192.168.1.10:8000/api/ping/")
    }

    @Test func theExplicitPortSettingWinsOverATypedOne() {
        #expect(
            config("http://host.local:8000", port: 9000).url(path: "/x/")?.absoluteString
                == "https://host.local:9000/x/"
        )
    }

    @Test func queryItemsAreEncoded() {
        let url = config("tube.example.com").url(
            path: "/api/search/",
            queryItems: [URLQueryItem(name: "query", value: "a b&c")]
        )
        #expect(url?.absoluteString == "https://tube.example.com/api/search/?query=a%20b%26c")
    }

    @Test func anAbsoluteMediaURLIsReturnedUnchanged() {
        let absolute = "https://img.youtube.com/vi/abc/mqdefault.jpg"
        #expect(config("tube.example.com").fullURL(for: absolute)?.absoluteString == absolute)
    }

    @Test func anEmptyAddressHasNoURL() {
        #expect(config("   ").url(path: "/api/ping/") == nil)
    }

    @Test func serverURLMatchIsExactOnTheHost() {
        let config = config("https://tube.example.com/ta")
        #expect(config.isServerURL(URL(string: "https://TUBE.example.com/cache/x.jpg")!))
        #expect(!config.isServerURL(URL(string: "https://tube.example.com.evil.test/x.jpg")!))
        #expect(!config.isServerURL(URL(string: "https://img.youtube.com/x.jpg")!))
    }

    @Test func noAuthHeaderWithoutAToken() {
        #expect(config("host", token: "").authHeaders.isEmpty)
        #expect(config("host", token: "abc").authHeaders == ["Authorization": "Token abc"])
    }
}
