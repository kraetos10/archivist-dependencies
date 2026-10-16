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

    // MARK: - Comments

    /// The shape `/api/video/{id}/comment/` returns: replies nested under
    /// their parent, every field the server sends, likes as `likecount`.
    @Test func commentDecodesItsReplyThread() throws {
        let json = """
        [{
          "comment_id": "c1",
          "comment_text": "Great video",
          "comment_timestamp": 1700000000,
          "comment_time_text": "2023-11-14",
          "comment_likecount": 1200,
          "comment_is_favorited": true,
          "comment_author": "@viewer",
          "comment_author_id": "UC_viewer",
          "comment_author_is_uploader": false,
          "comment_author_thumbnail": "https://yt3.ggpht.com/a.jpg",
          "comment_parent": "root",
          "comment_replies": [{
            "comment_id": "c1.r1",
            "comment_text": "Thanks!",
            "comment_timestamp": 1700000100,
            "comment_likecount": 40,
            "comment_author": "@channel",
            "comment_author_id": "UC_channel",
            "comment_author_is_uploader": true,
            "comment_author_thumbnail": "https://yt3.ggpht.com/b.jpg",
            "comment_parent": "c1",
            "comment_replies": []
          }]
        }]
        """
        let comments = try decode([VideoComment].self, json)
        let comment = try #require(comments.first)

        #expect(comment.commentLikeCount == 1200)
        #expect(comment.commentParent == "root")
        #expect(comment.authorThumbnailURL?.absoluteString == "https://yt3.ggpht.com/a.jpg")
        #expect(comment.authorInitial == "V")
        #expect(comment.replyCount == 1)
        let reply = try #require(comment.replies.first)
        #expect(reply.isByUploader)
        #expect(reply.commentParent == "c1")
        #expect(comments.totalCommentCount == 2)
    }

    @Test func commentWithoutRepliesStillDecodes() throws {
        let comment = try decode(VideoComment.self, #"{"comment_id": "c1", "comment_text": "Hi"}"#)

        #expect(comment.replies.isEmpty)
        #expect(comment.replyCount == 0)
        #expect(!comment.isByUploader)
        #expect(comment.authorInitial == "?")
    }

    /// Nothing in the format stops a reply to a reply; those flatten into
    /// the thread instead of nesting deeper.
    @Test func deeperRepliesFlattenDepthFirst() throws {
        let json = """
        {"comment_id": "c1", "comment_replies": [
          {"comment_id": "r1", "comment_replies": [{"comment_id": "r1a"}]},
          {"comment_id": "r2"}
        ]}
        """
        let comment = try decode(VideoComment.self, json)

        #expect(comment.flattenedReplies.map(\.commentId) == ["r1", "r1a", "r2"])
        #expect(comment.replyCount == 3)
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
