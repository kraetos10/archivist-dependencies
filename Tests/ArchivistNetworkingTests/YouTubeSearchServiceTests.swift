@testable import ArchivistNetworking
import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

// An extension, not its own suite: both share `StubURLProtocol`'s handler, so
// they must run serialised together.
extension NetworkAPIRequestTests {
    private func json(_ text: String) -> StubURLProtocol.Response {
        .init(statusCode: 200, body: Data(text.utf8))
    }

    private func failure(
        _ status: Int,
        _ text: String
    ) -> StubURLProtocol.Response {
        .init(statusCode: status, body: Data(text.utf8))
    }

    @Test func durationsParse() {
        #expect(ISO8601Duration.seconds("PT4M5S") == 245)
        #expect(ISO8601Duration.seconds("PT1H2M3S") == 3_723)
        #expect(ISO8601Duration.seconds("PT45S") == 45)
        #expect(ISO8601Duration.seconds("P1DT1H") == 90_000)
        #expect(ISO8601Duration.seconds("garbage") == nil)
    }

    @Test func videoSearchEnrichesResultsInOrderAndSendsTheKeyInAHeader() async throws {
        let session = StubURLProtocol.session { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/search") {
                return json("""
                {"nextPageToken":"NEXT","items":[
                  {"id":{"videoId":"bbb"}},{"id":{"videoId":"aaa"}}]}
                """)
            }
            return json("""
            {"items":[
              {"id":"aaa","snippet":{"title":"A","channelId":"UC1","channelTitle":"One",
                 "publishedAt":"2024-05-01T10:00:00Z",
                 "thumbnails":{"medium":{"url":"https://img/a.jpg"}}},
               "contentDetails":{"duration":"PT4M5S"},"statistics":{"viewCount":"1200"}},
              {"id":"bbb","snippet":{"title":"B","channelId":"UC2","channelTitle":"Two"},
               "contentDetails":{"duration":"PT1H"},"statistics":{}}]}
            """)
        }
        let page = try await withDependencies {
            $0.urlSession = session
        } operation: {
            try await YouTubeSearchService.liveValue.searchVideos("KEY", "swift", .relevance, nil)
        }

        #expect(page.items.map(\.videoId) == ["bbb", "aaa"])
        #expect(page.nextPageToken == "NEXT")
        #expect(page.items[1].durationSeconds == 245)
        #expect(page.items[1].viewCount == 1_200)
        #expect(page.items[1].thumbnailURL?.absoluteString == "https://img/a.jpg")
        #expect(page.items[0].viewCount == nil)

        let sent = StubURLProtocol.requests.value
        #expect(sent.allSatisfy { $0.value(forHTTPHeaderField: "X-Goog-Api-Key") == "KEY" })
        #expect(sent.allSatisfy { $0.url?.query?.contains("KEY") == false })
        #expect(sent.first?.url?.host == "www.googleapis.com")
    }

    @Test func channelUploadsUseTheUploadsPlaylist() async throws {
        let session = StubURLProtocol.session { request in
            if request.url?.path.hasSuffix("/playlistItems") == true {
                return json(#"{"items":[{"contentDetails":{"videoId":"v1"}}]}"#)
            }
            return json(#"{"items":[]}"#)
        }
        let page = try await withDependencies {
            $0.urlSession = session
        } operation: {
            try await YouTubeSearchService.liveValue.channelUploads("KEY", "UCabc123", nil)
        }
        #expect(page.items.isEmpty)
        let query = StubURLProtocol.requests.value.first?.url?.query ?? ""
        #expect(query.contains("playlistId=UUabc123"))
    }

    @Test(arguments: [
        (403, #"{"error":{"code":403,"message":"x","errors":[{"reason":"quotaExceeded"}]}}"#, YouTubeError.quotaExceeded),
        (403, #"{"error":{"code":403,"message":"x","errors":[{"reason":"accessNotConfigured"}]}}"#, YouTubeError.apiNotEnabled),
        (400, #"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","details":[{"reason":"API_KEY_INVALID"}]}}"#, YouTubeError.invalidKey),
        (500, #"{"error":{"code":500,"message":"boom"}}"#, YouTubeError.rejected("boom")),
        (502, "not json", YouTubeError.rejected("HTTP 502"))
    ])
    func errorsAreClassified(
        status: Int,
        body: String,
        expected: YouTubeError
    ) async {
        let session = StubURLProtocol.session { _ in failure(status, body) }
        await withDependencies {
            $0.urlSession = session
        } operation: {
            await #expect(throws: expected) {
                try await YouTubeSearchService.liveValue.validateKey("KEY")
            }
        }
    }

    @Test func hiddenSubscriberCountsAreNil() async throws {
        let session = StubURLProtocol.session { _ in
            json("""
            {"items":[{"id":"UC1","snippet":{"title":"One"},
              "statistics":{"subscriberCount":"5","hiddenSubscriberCount":true}}]}
            """)
        }
        let channel = try await withDependencies {
            $0.urlSession = session
        } operation: {
            try await YouTubeSearchService.liveValue.channelDetails("KEY", "UC1")
        }
        #expect(channel.subscriberCount == nil)
        #expect(channel.title == "One")
    }
}
