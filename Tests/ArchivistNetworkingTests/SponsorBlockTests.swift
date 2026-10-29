@testable import ArchivistNetworking
import Foundation
import Testing

/// `SponsorBlock` rides on every video the server returns, so it must never
/// be the reason a page fails to decode.
@Suite(.timeLimit(.minutes(1)))
struct SponsorBlockTests {
    private func decodeVideo(sponsorblock: String) throws -> VideoResponse {
        let json = """
        {
          "youtube_id": "abc",
          "title": "A video",
          "channel": { "channel_id": "UC1", "channel_name": "Channel" },
          "sponsorblock": \(sponsorblock)
        }
        """
        return try JSONDecoder().decode(VideoResponse.self, from: Data(json.utf8))
    }

    private func segment(
        _ start: Double,
        _ end: Double,
        action: String = "skip",
        uuid: String = "u"
    ) -> String {
        """
        { "UUID": "\(uuid)", "actionType": "\(action)", "category": "sponsor",
          "locked": 0, "votes": 3, "videoDuration": 600, "segment": [\(start), \(end)] }
        """
    }

    @Test func decodesSegmentsFromTheServerShape() throws {
        let video = try decodeVideo(sponsorblock: """
        { "is_enabled": true, "last_refresh": 1, "has_unlocked": false,
          "segments": [\(segment(10, 25.5))] }
        """)

        #expect(video.sponsorblock?.isEnabled == true)
        #expect(video.sponsorblock?.segments.first?.start == 10)
        #expect(video.sponsorblock?.segments.first?.end == 25.5)
        #expect(video.sponsorSkipRanges == [10..<25.5])
    }

    @Test func aVideoWithoutSponsorBlockDataHasNothingToSkip() throws {
        let video = try decodeVideo(sponsorblock: "null")

        #expect(video.sponsorblock == nil)
        #expect(video.sponsorSkipRanges.isEmpty)
    }

    @Test func aMalformedSegmentIsDroppedWithoutFailingTheVideo() throws {
        let video = try decodeVideo(sponsorblock: """
        { "is_enabled": true, "segments": [
          { "UUID": "bad", "actionType": "skip", "category": "sponsor", "segment": [5] },
          \(segment(30, 40, uuid: "good"))
        ] }
        """)

        #expect(video.sponsorblock?.segments.map(\.uuid) == ["good"])
    }

    @Test func onlySkipActionsWithTimeInThemAreSkipped() throws {
        let video = try decodeVideo(sponsorblock: """
        { "is_enabled": true, "segments": [
          \(segment(0, 5, action: "mute")),
          \(segment(50, 50)),
          \(segment(80, 90))
        ] }
        """)

        #expect(video.sponsorSkipRanges == [80..<90])
    }

    @Test func rangesComeEarliestFirst() throws {
        let video = try decodeVideo(sponsorblock: """
        { "is_enabled": true, "segments": [\(segment(300, 320)), \(segment(10, 20))] }
        """)

        #expect(video.sponsorSkipRanges == [10..<20, 300..<320])
    }

    @Test func nothingIsSkippedWhenTheServerHasItSwitchedOffForTheVideo() throws {
        let video = try decodeVideo(sponsorblock: """
        { "is_enabled": false, "segments": [\(segment(10, 20))] }
        """)

        #expect(video.sponsorSkipRanges.isEmpty)
    }

    @Test func theVideoHasSponsorBlockOnlyWhenThereIsSomethingToSkip() throws {
        let withSegments = try decodeVideo(sponsorblock: """
        { "is_enabled": true, "segments": [\(segment(10, 20))] }
        """)
        let switchedOff = try decodeVideo(sponsorblock: """
        { "is_enabled": false, "segments": [\(segment(10, 20))] }
        """)
        let onlyMute = try decodeVideo(sponsorblock: """
        { "is_enabled": true, "segments": [\(segment(10, 20, action: "mute"))] }
        """)
        let none = try decodeVideo(sponsorblock: "null")

        #expect(withSegments.hasSponsorBlock)
        #expect(!switchedOff.hasSponsorBlock)
        #expect(!onlyMute.hasSponsorBlock)
        #expect(!none.hasSponsorBlock)
    }
}
