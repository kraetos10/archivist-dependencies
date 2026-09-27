@testable import ArchivistNetworking
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct DecodingTests {
    private func decode<T: Decodable>(
        _ type: T.Type,
        _ json: String
    ) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test(arguments: [
        ("\"videos\"", VideoType.videos),
        ("\"streams\"", VideoType.streams),
        ("\"shorts\"", VideoType.shorts),
        ("\"podcasts\"", VideoType.unknown)
    ])
    func videoTypeFallsBackToUnknown(json: String, expected: VideoType) throws {
        #expect(try decode(VideoType.self, json) == expected)
    }

    @Test func downloadWithUnknownStatusAndTypeStillDecodes() throws {
        let json = """
        {
          "youtube_id": "abc",
          "channel_id": "UC1",
          "status": "archived",
          "vid_type": "livestream_replay"
        }
        """
        let download = try decode(DownloadResponse.self, json)
        #expect(download.status == .unknown)
        #expect(download.vidType == .unknown)
    }

    @Test func downloadStatusKnownValues() throws {
        #expect(try decode(DownloadStatus.self, "\"pending\"") == .pending)
        #expect(try decode(DownloadStatus.self, "\"ignore\"") == .ignore)
        #expect(try decode(DownloadStatus.self, "\"priority\"") == .priority)
    }

    @Test func playlistTypeFallsBackToUnknown() throws {
        #expect(try decode(PlaylistType.self, "\"regular\"") == .regular)
        #expect(try decode(PlaylistType.self, "\"custom\"") == .custom)
        #expect(try decode(PlaylistType.self, "\"smart\"") == .unknown)
    }

    @Test func aNonStringEnumValueStillFails() {
        #expect(throws: DecodingError.self) {
            try decode(PlaylistType.self, "42")
        }
    }

    @Test func paginatedPageWithANewVideoTypeDecodes() throws {
        let json = """
        {
          "data": [
            {
              "youtube_id": "v1",
              "title": "One",
              "channel": { "channel_id": "UC1", "channel_name": "Chan" },
              "vid_type": "brand_new_type"
            }
          ],
          "paginate": {
            "page_size": 12, "page_from": 0, "current_page": 1, "last_page": 1,
            "total_hits": 1, "next_pages": [], "prev_pages": null, "max_hits": false,
            "params": null
          }
        }
        """
        let page = try decode(PaginatedResponse<VideoResponse>.self, json)
        #expect(page.data.first?.vidType == .unknown)
    }

    @Test func subscriberCountsUseCompactNotation() {
        let formatted = ChannelResponse.placeholder.formattedSubs
        #expect(formatted == 12345.formatted(.number.notation(.compactName)))
    }
}
