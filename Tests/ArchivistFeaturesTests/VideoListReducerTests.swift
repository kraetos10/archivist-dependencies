import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(
    .serialized,
    .timeLimit(.minutes(1)),
    .dependencies {
        // The list observes completed device downloads.
        try $0.bootstrapInMemoryDatabase()
        $0.topShelf = TopShelfClient { _, _ in }
        // Every refresh also reloads the home Queue strip.
        $0.downloadService.getDownloads = { _, _, _, _, _, _ in TestFixtures.emptyDownloads }
    }
)
struct VideoListReducerTests {
    let config = TestFixtures.serverConfig

    private func errorAlert(_ error: any Error) -> AlertState<VideoListReducer.AlertAction> {
        AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(error.localizedDescription)
        }
    }

    // MARK: - Paging

    /// Page one is a full refresh: it replaces whatever was listed.
    @Test func theFirstPageReplacesTheList() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.videos = [TestFixtures.watchedVideo]
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, page, sort, _, _, _, _, _ in
                #expect(page == 1)
                #expect(sort == VideoSortOrder.published.apiValue)
                return TestFixtures.paginatedVideos
            }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.isLoading = false
            $0.recomputeHomeSections()
        }
        await store.receive(\.queuedDownloadsResult)
    }

    @Test func laterPagesAppend() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.videos = [TestFixtures.watchedVideo]
        state.lastPage = 2
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, page, _, _, _, _, _, _ in
                TestFixtures.paginatedVideosMultiPage(page: page, lastPage: 2)
            }
        }

        await store.send(.view(.lastItemAppeared)) {
            $0.isLoadingMore = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos.append(contentsOf: [TestFixtures.video1, TestFixtures.video2])
            $0.currentPage = 2
            $0.isLoadingMore = false
            $0.recomputeHomeSections()
        }
        // The last page is in: nothing more to load.
        await store.send(.view(.lastItemAppeared))
    }

    /// A refresh cancels a page still loading, so the stale page can't
    /// append to the fresh list.
    @Test func refreshCancelsThePageStillLoading() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.videos = [TestFixtures.watchedVideo]
        state.lastPage = 2
        state.hasLoaded = true
        let staleGate = TestGate()
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, page, _, _, _, _, _, _ in
                if page == 2 {
                    await staleGate.wait()
                    return TestFixtures.paginatedVideosMultiPage(page: 2, lastPage: 2)
                }
                return TestFixtures.paginatedVideos
            }
        }

        await store.send(.view(.lastItemAppeared)) {
            $0.isLoadingMore = true
        }
        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
            $0.isLoadingMore = false
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoading = false
            $0.recomputeHomeSections()
        }
        await store.receive(\.queuedDownloadsResult)
        staleGate.open()
    }

    @Test func aFailedLoadSaysSo() async {
        let failure = URLError(.timedOut)
        let store = TestStore(initialState: VideoListReducer.State(serverConfig: config)) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in throw failure }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.videosResult.failure) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.destination = .alert(errorAlert(failure))
        }
        await store.receive(\.queuedDownloadsResult)
    }

    // MARK: - Context-menu writes

    @Test func markingWatchedRefreshesTheVideo() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.videos = [TestFixtures.video1]
        let watched = LockIsolated<[Bool]>([])
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, _, isWatched in watched.withValue { $0.append(isWatched) } }
            $0.videoService.getVideo = { _, _ in TestFixtures.watchedVideo }
        }

        // The entry point tvOS Search uses.
        await store.send(.markAsWatched(TestFixtures.video1))
        await store.receive(\.markWatchedResult.success)
        await store.receive(\.videoRefreshed) {
            $0.videos.append(TestFixtures.watchedVideo)
            $0.recomputeHomeSections()
        }
        #expect(watched.value == [true])
    }

    @Test func aFailedMarkWatchedShowsAnAlert() async {
        let failure = URLError(.notConnectedToInternet)
        let store = TestStore(initialState: VideoListReducer.State(serverConfig: config)) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, _, _ in throw failure }
        }

        await store.send(.view(.markAsWatchedTapped(TestFixtures.video1)))
        await store.receive(\.markWatchedResult.failure) {
            $0.destination = .alert(errorAlert(failure))
        }
    }

    /// A late failure mustn't close the video the user has since opened.
    @Test func anErrorNeverReplacesAnOpenVideo() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.destination = .videoDetail(
            VideoDetailReducer.State(serverConfig: config, video: TestFixtures.video2)
        )
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, _, _ in throw URLError(.timedOut) }
        }

        await store.send(.markAsWatched(TestFixtures.video1))
        await store.receive(\.markWatchedResult.failure)
    }

    @Test func deletingFromTheServerDropsTheVideo() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.videos = [TestFixtures.video1, TestFixtures.video2]
        let deleted = LockIsolated<[String]>([])
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.deleteVideo = { _, id in deleted.withValue { $0.append(id) } }
        }

        await store.send(.deleteFromServer(TestFixtures.video1))
        await store.receive(\.contextDeleteResult.success) {
            $0.videos.remove(id: TestFixtures.video1.videoId)
            $0.recomputeHomeSections()
        }
        #expect(deleted.value == [TestFixtures.video1.videoId])
    }

    /// "View All" lists hand their context-menu writes up to this reducer.
    @Test func aViewAllListsMarkWatchedFailureShowsAnAlert() async throws {
        let failure = URLError(.timedOut)
        var state = VideoListReducer.State(serverConfig: config)
        state.path.append(.filteredList(FilteredVideoListReducer.State(serverConfig: config, filter: .all)))
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, _, _ in throw failure }
        }
        let listID = try #require(store.state.path.ids.first)

        await store.send(
            .path(.element(id: listID, action: .filteredList(.delegate(.markAsWatchedRequested(TestFixtures.video1)))))
        )
        await store.receive(\.markWatchedResult.failure) {
            $0.destination = .alert(errorAlert(failure))
        }
    }

    // MARK: - Presentations

    @Test func addToPlaylistOpensThePicker() async {
        let store = TestStore(initialState: VideoListReducer.State(serverConfig: config)) {
            VideoListReducer()
        }

        await store.send(.view(.addToPlaylistTapped(TestFixtures.video1))) {
            $0.destination = .playlistPicker(
                PlaylistPickerReducer.State(serverConfig: config, videoId: TestFixtures.video1.videoId)
            )
        }
    }

    @Test func addingAVideoClosesTheFormAndRefreshes() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.destination = .addVideo(AddVideoReducer.State(serverConfig: config))
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.paginatedVideos }
        }

        await store.send(.destination(.presented(.addVideo(.addResult(.success(())))))) {
            $0.destination = nil
            $0.isLoading = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.isLoading = false
            $0.hasLoaded = true
            $0.recomputeHomeSections()
        }
        await store.receive(\.queuedDownloadsResult)
    }

    #if os(iOS)
    @Test func dismissingTheVideoRefreshesIt() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.videos = [TestFixtures.video1]
        state.destination = .videoDetail(
            VideoDetailReducer.State(serverConfig: config, video: TestFixtures.video1)
        )
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.getVideo = { _, _ in TestFixtures.video1 }
        }

        await store.send(
            .destination(.presented(.videoDetail(.delegate(.didDismiss(TestFixtures.video1.videoId)))))
        ) {
            $0.destination = nil
        }
        await store.receive(\.videoRefreshed) {
            $0.recomputeHomeSections()
        }
    }
    #endif

    // MARK: - Queue strip

    private nonisolated static func downloadsPage(
        _ data: [DownloadResponse],
        page: Int,
        lastPage: Int
    ) -> PaginatedResponse<DownloadResponse> {
        PaginatedResponse(
            data: data,
            paginate: PaginatedResponse<DownloadResponse>.PaginateInfo(
                pageSize: 25,
                pageFrom: 0,
                currentPage: page,
                lastPage: lastPage,
                totalHits: data.count,
                nextPages: [],
                prevPages: nil,
                maxHits: false,
                params: nil
            )
        )
    }

    /// A refresh loads the strip in the Queue screen's default order,
    /// newest first: the server's order, reversed.
    @Test func refreshLoadsTheQueueStripNewestFirst() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.paginatedVideos }
            $0.downloadService.getDownloads = { _, page, filter, _, _, _ in
                #expect(page == 1)
                #expect(filter == "pending")
                return TestFixtures.paginatedDownloads
            }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.isLoading = false
            $0.recomputeHomeSections()
        }
        await store.receive(\.queuedDownloadsResult.success) {
            $0.queuedDownloads = [TestFixtures.download2, TestFixtures.download1]
        }
    }

    /// Newest first over several pages reads from the last page, topping
    /// up from the one before when the last is short — as the Queue
    /// screen does.
    @Test func newestFirstReadsFromTheLastPage() async {
        let pages = LockIsolated<[Int]>([])
        let store = TestStore(initialState: VideoListReducer.State(serverConfig: config)) {
            VideoListReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, page, _, _, _, _ in
                pages.withValue { $0.append(page) }
                switch page {
                case 3: return Self.downloadsPage([TestFixtures.download1], page: 3, lastPage: 3)
                case 2: return Self.downloadsPage([TestFixtures.download2], page: 2, lastPage: 3)
                default: return Self.downloadsPage([], page: 1, lastPage: 3)
                }
            }
        }

        await store.send(.refreshQueue)
        await store.receive(\.queuedDownloadsResult.success) {
            $0.queuedDownloads = [TestFixtures.download1, TestFixtures.download2]
        }
        expectNoDifference(pages.value, [1, 3, 2])
    }

    @Test func oldestFirstKeepsTheServerOrder() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.$queueSortOrder.withLock { $0 = .oldestFirst }
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in TestFixtures.paginatedDownloads }
        }

        await store.send(.refreshQueue)
        await store.receive(\.queuedDownloadsResult.success) {
            $0.queuedDownloads = [TestFixtures.download1, TestFixtures.download2]
        }
        store.state.$queueSortOrder.withLock { $0 = .newestFirst }
    }

    /// Nothing in the strip can be watched, and downloading is a grown-up's
    /// call: child mode hides it.
    @Test func childModeHidesTheQueueStrip() {
        var state = VideoListReducer.State(serverConfig: config)
        state.queuedDownloads = [TestFixtures.download1]
        #expect(state.queueStripItems.map(\.id) == ["dl_video_1"])

        state.$childModeEnabled.withLock { $0 = true }
        #expect(state.queueStripItems.isEmpty)
        state.$childModeEnabled.withLock { $0 = false }
    }

    /// A tap downloads straight away: the card spins at once, and keeps
    /// spinning while the server still lists the video as queued (a bumped
    /// video is only dropped from the queue once it has downloaded).
    @Test func tappingAQueuedCardDownloadsIt() async {
        let bumped = LockIsolated<[String]>([])
        var state = VideoListReducer.State(serverConfig: config)
        state.queuedDownloads = [TestFixtures.download1, TestFixtures.download2]
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.downloadService.updateDownload = { _, id, status in
                #expect(status == "priority")
                bumped.withValue { $0.append(id) }
            }
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in
                Self.downloadsPage([TestFixtures.download1, TestFixtures.download2], page: 1, lastPage: 1)
            }
        }

        await store.send(.view(.queuedDownloadTapped(TestFixtures.download1))) {
            $0.startedQueueDownloadIDs = ["dl_video_1"]
        }
        expectNoDifference(
            store.state.queueStripItems,
            [
                QueueStripItem(download: TestFixtures.download1, isDownloadStarted: true),
                QueueStripItem(download: TestFixtures.download2, isDownloadStarted: false)
            ]
        )
        await store.receive(\.queueBumpResult)
        await store.receive(\.queuedDownloadsResult) {
            $0.queuedDownloads = [TestFixtures.download2, TestFixtures.download1]
        }
        // Still queued on the server, still spinning.
        #expect(store.state.queueStripItems.first { $0.id == "dl_video_1" }?.isDownloadStarted == true)
        // A second tap on a spinning card does nothing.
        await store.send(.view(.queuedDownloadTapped(TestFixtures.download1)))
        expectNoDifference(bumped.value, ["dl_video_1"])
    }

    /// Once the server stops listing a started video, it's forgotten.
    @Test func aDownloadedVideoIsForgotten() async {
        var state = VideoListReducer.State(serverConfig: config)
        state.queuedDownloads = [TestFixtures.download1, TestFixtures.download2]
        state.startedQueueDownloadIDs = ["dl_video_1"]
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in
                Self.downloadsPage([TestFixtures.download2], page: 1, lastPage: 1)
            }
        }

        await store.send(.refreshQueue)
        await store.receive(\.queuedDownloadsResult) {
            $0.queuedDownloads = [TestFixtures.download2]
            $0.startedQueueDownloadIDs = []
        }
    }

    /// A bump the server refuses stops the spinner and says why.
    @Test func aRefusedDownloadComesBack() async {
        let failure = URLError(.badServerResponse)
        var state = VideoListReducer.State(serverConfig: config)
        state.queuedDownloads = [TestFixtures.download1]
        let store = TestStore(initialState: state) {
            VideoListReducer()
        } withDependencies: {
            $0.downloadService.updateDownload = { _, _, _ in throw failure }
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in
                Self.downloadsPage([TestFixtures.download1], page: 1, lastPage: 1)
            }
        }

        await store.send(.view(.queuedDownloadTapped(TestFixtures.download1))) {
            $0.startedQueueDownloadIDs = ["dl_video_1"]
        }
        await store.receive(\.queueBumpResult) {
            $0.startedQueueDownloadIDs = []
            $0.destination = .alert(errorAlert(failure))
        }
        await store.receive(\.queuedDownloadsResult)
        #expect(store.state.queueStripItems.map(\.isDownloadStarted) == [false])
    }

    @Test func queueViewAllOpensTheQueueScreen() async {
        let store = TestStore(initialState: VideoListReducer.State(serverConfig: config)) {
            VideoListReducer()
        }

        await store.send(.view(.queueViewAllTapped)) {
            $0.path.append(.queue(DownloadsReducer.State(serverConfig: self.config)))
        }
    }
}
