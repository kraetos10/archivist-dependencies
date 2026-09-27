#if os(watchOS)
@testable import ArchivistNetworking
@testable import ArchivistWatch
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct WatchHelpersTests {
    @Test(arguments: [
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"),
        ("https://www.youtube.com/watch?feature=share&v=abc_DEF-123", "abc_DEF-123"),
        ("https://youtu.be/dQw4w9WgXcQ?t=42", "dQw4w9WgXcQ"),
        ("https://youtube.com/shorts/SHORT123", "SHORT123"),
        ("https://www.youtube.com/live/LIVE_1", "LIVE_1"),
        ("  dQw4w9WgXcQ \n", "dQw4w9WgXcQ")
    ])
    @MainActor
    func extractsVideoIds(input: String, expected: String) {
        #expect(WatchAddDownloadViewModel.videoId(from: input) == expected)
    }

    @Test(arguments: ["", "   ", "not a video", "https://example.com/page"])
    @MainActor
    func rejectsTextWithoutAVideoId(input: String) {
        #expect(WatchAddDownloadViewModel.videoId(from: input) == nil)
    }

    @Test func downloadItemSurvivesTheTaskDescription() throws {
        let item = WatchDownloadItem(
            videoId: "v1",
            title: "Title",
            channelName: "Channel",
            mediaUrl: "/media/v1.mp4",
            duration: 90,
            durationStr: "1:30",
            thumbPath: "/cache/v1.jpg"
        )
        let restored = try #require(WatchDownloadItem(taskDescription: item.taskDescription))
        #expect(restored == item)
        #expect(WatchDownloadItem(taskDescription: nil) == nil)
        #expect(WatchDownloadItem(taskDescription: "garbage") == nil)
    }

    @Test func downloadItemBuildsItsRecord() {
        let item = WatchDownloadItem(
            videoId: "v1",
            title: "Title",
            channelName: "Channel",
            mediaUrl: nil,
            duration: 90,
            durationStr: "1:30",
            thumbPath: nil
        )
        let record = item.record(fileSize: 2048, downloadedAt: Date(timeIntervalSince1970: 100))
        #expect(record.id == "v1")
        #expect(record.fileSize == 2048)
        #expect(record.downloadedAt == 100)
        #expect(record.lastPlayedPosition == 0)
    }

    @Test func onlySuccessfulResponsesAreKept() throws {
        let url = try #require(URL(string: "https://tube.example.com/media/v1.mp4"))
        func response(_ code: Int) -> HTTPURLResponse? {
            HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)
        }
        #expect(WatchDownloadError.validate(response(200)) == nil)
        #expect(WatchDownloadError.validate(response(206)) == nil)
        #expect(WatchDownloadError.validate(response(403)) == .httpStatus(403))
        #expect(WatchDownloadError.validate(response(404)) == .httpStatus(404))
        #expect(WatchDownloadError.validate(nil) == .downloadFailed)
    }

    @Test func pagingDropsAPageFromASupersededLoad() {
        var paging = WatchPaging()
        let first = paging.firstPageRequest()
        let acceptedFirst = paging.accept(WatchFixtures.paginate(page: 1, lastPage: 3), for: first)
        #expect(acceptedFirst)
        let next = paging.nextPageRequest()
        #expect(next?.page == 2)

        _ = paging.firstPageRequest()
        if let next {
            let acceptedStale = paging.accept(WatchFixtures.paginate(page: 2, lastPage: 3), for: next)
            #expect(!acceptedStale)
        }
        #expect(paging.currentPage == 1)
    }

    @Test func pagingStopsAtTheLastPage() {
        var paging = WatchPaging()
        #expect(paging.nextPageRequest() == nil)
        let first = paging.firstPageRequest()
        _ = paging.accept(WatchFixtures.paginate(page: 1, lastPage: 1), for: first)
        #expect(paging.nextPageRequest() == nil)
    }

    @Test func startedVideosShowTimeRemaining() {
        #expect(
            WatchVideoRowModel.subtitle(watchProgress: 0.5, remainingSeconds: 600, durationStr: "20:00")
                == WatchVideoRowModel.remainingText(seconds: 600)
        )
        #expect(WatchVideoRowModel.subtitle(watchProgress: 0, remainingSeconds: nil, durationStr: "20:00") == "20:00")
    }
}
#endif
