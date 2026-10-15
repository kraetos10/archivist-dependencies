import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import SQLiteData
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(
    .serialized,
    .timeLimit(.minutes(1)),
    .dependencies { $0.defaultDatabase = try TubeData.shared.inMemoryDatabase() }
)
struct ChannelDetailReducerTests {
    let config = TestFixtures.serverConfig

    private func makeState() -> ChannelDetailReducer.State {
        ChannelDetailReducer.State(
            serverConfig: config,
            channel: TestFixtures.channel1
        )
    }

    // MARK: - Loading

    @Test func viewDidAppearLoadsVideosAndDownloads() async {
        let downloadsGate = TestGate()
        let store = TestStore(initialState: makeState()) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.paginatedVideos }
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in
                await downloadsGate.wait()
                return TestFixtures.paginatedDownloads
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingVideos = true
            $0.isLoadingDownloads = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1, TestFixtures.video2])
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
        downloadsGate.open()
        await store.receive(\.downloadsResult.success) {
            $0.pendingDownloads = IdentifiedArrayOf(uniqueElements: [TestFixtures.download2, TestFixtures.download1])
            $0.isLoadingDownloads = false
            $0.hasLoadedDownloads = true
        }
    }

    @Test func viewDidAppearSkipsWhenAlreadyLoaded() async {
        var initialState = makeState()
        initialState.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1])
        initialState.hasLoadedVideos = true
        initialState.pendingDownloads = IdentifiedArrayOf(uniqueElements: [TestFixtures.download1])
        initialState.hasLoadedDownloads = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.view(.viewDidAppear))
    }

    @Test func videosResultPopulatesVideos() async {
        var initialState = makeState()
        initialState.isLoadingVideos = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.videosResult(.success(TestFixtures.paginatedVideos))) {
            $0.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1, TestFixtures.video2])
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
    }

    @Test func videosResultFailureClearsLoading() async {
        var initialState = makeState()
        initialState.isLoadingVideos = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.videosResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
    }

    @Test func lastVideoAppearedLoadsNextPage() async {
        var initialState = makeState()
        initialState.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1])
        initialState.hasLoadedVideos = true
        initialState.currentPage = 1
        initialState.lastPage = 2

        let page2 = TestFixtures.paginatedVideosMultiPage(page: 2, lastPage: 2)

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in page2 }
        }

        await store.send(.view(.lastVideoAppeared)) {
            $0.isLoadingMoreVideos = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1, TestFixtures.video2])
            $0.currentPage = 2
            $0.lastPage = 2
            $0.isLoadingMoreVideos = false
            $0.hasLoadedVideos = true
        }
    }

    @Test func pullToRefreshReplacesTheVideos() async {
        var initialState = makeState()
        // video1 has since been deleted on the server; refresh must drop it
        // rather than keep it and append the new page after it.
        initialState.videos = [TestFixtures.video1]
        initialState.hasLoadedVideos = true
        initialState.pendingDownloads = [TestFixtures.download1]
        initialState.hasLoadedDownloads = true
        initialState.currentPage = 2
        initialState.lastPage = 2

        let page1 = PaginatedResponse<VideoResponse>(
            data: [TestFixtures.video2],
            paginate: TestFixtures.paginatedVideos.paginate
        )
        let downloadsGate = TestGate()
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in page1 }
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in
                await downloadsGate.wait()
                return TestFixtures.emptyDownloads
            }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoadingVideos = true
            $0.isLoadingDownloads = true
            $0.currentPage = 1
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video2]
            $0.lastPage = 1
            $0.isLoadingVideos = false
        }
        downloadsGate.open()
        await store.receive(\.downloadsResult.success) {
            $0.pendingDownloads = []
            $0.isLoadingDownloads = false
        }
    }

    /// A page still loading for the old sort order must not land in the
    /// list fetched for the new one.
    @Test func sortChangeCancelsThePageStillLoading() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1]
        initialState.hasLoadedVideos = true
        initialState.currentPage = 1
        initialState.lastPage = 3

        let staleGate = TestGate()
        let newSortPage = PaginatedResponse<VideoResponse>(
            data: [TestFixtures.video2],
            paginate: TestFixtures.paginatedVideos.paginate
        )
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, sort, _, _, _, _, _ in
                if sort == VideoSortOrder.published.apiValue {
                    await staleGate.wait()
                    return TestFixtures.paginatedVideosMultiPage(page: 2, lastPage: 3)
                }
                return newSortPage
            }
        }

        await store.send(.view(.lastVideoAppeared)) {
            $0.isLoadingMoreVideos = true
        }
        await store.send(.view(.videoSortOrderChanged(.views))) {
            $0.videoSortOrder = .views
            $0.videos = []
            $0.lastPage = 1
            $0.hasLoadedVideos = false
            $0.isLoadingVideos = true
            $0.isLoadingMoreVideos = false
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video2]
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
        // Releasing the old request delivers nothing: it was cancelled.
        staleGate.open()
    }

    @Test func downloadsResultFailureClearsLoading() async {
        var initialState = makeState()
        initialState.isLoadingDownloads = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.downloadsResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoadingDownloads = false
            $0.hasLoadedDownloads = true
        }
    }

    @Test func refreshPendingDownloadsReloadsWithoutPlaceholders() async {
        var initialState = makeState()
        initialState.pendingDownloads = [TestFixtures.download1]
        initialState.hasLoadedDownloads = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in TestFixtures.emptyDownloads }
        }

        await store.send(.refreshPendingDownloads)
        await store.receive(\.downloadsResult.success) {
            $0.pendingDownloads = []
        }
    }

    // MARK: - Selection

    @Test func videoCardTappedSendsTheUnwatchedVideosAfterIt() async {
        var initialState = makeState()
        initialState.videos = [
            TestFixtures.video1,
            TestFixtures.watchedVideo,
            TestFixtures.video2,
        ]
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.view(.videoCardTapped(TestFixtures.video1)))
        await store.receive(
            \.delegate,
            .videoSelected(TestFixtures.video1, nextVideos: [TestFixtures.video2])
        )
    }

    #if !os(tvOS)
    @Test func downloadCardTappedPresentsDownloadDetail() async {
        let store = TestStore(initialState: makeState()) {
            ChannelDetailReducer()
        }

        await store.send(.view(.downloadCardTapped(TestFixtures.download1))) {
            $0.downloadDetail = DownloadDetailReducer.State(
                serverConfig: self.config,
                download: TestFixtures.download1
            )
        }
    }
    #endif

    @Test func addToPlaylistPresentsThePicker() async {
        let store = TestStore(initialState: makeState()) {
            ChannelDetailReducer()
        }

        await store.send(.view(.addToPlaylistTapped(TestFixtures.video1))) {
            $0.playlistPicker = PlaylistPickerReducer.State(
                serverConfig: self.config,
                videoId: TestFixtures.video1.videoId
            )
        }
    }

    // MARK: - Watched

    @Test func markAsWatchedFlipsTheCardStraightAway() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1]
        let calls = LockIsolated<[Bool]>([])
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, _, isWatched in
                calls.withValue { $0.append(isWatched) }
            }
        }

        await store.send(.view(.markAsWatchedTapped(TestFixtures.video1))) {
            $0.videos[id: TestFixtures.video1.id] = TestFixtures.video1.settingWatched(true)
        }
        await store.receive(\.setWatchedResult)
        #expect(calls.value == [true])
    }

    @Test func markAsWatchedRollsBackWhenTheServerRefuses() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1]
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, _, _ in
                throw NSError(domain: "test", code: 0)
            }
        }

        await store.send(.view(.markAsWatchedTapped(TestFixtures.video1))) {
            $0.videos[id: TestFixtures.video1.id] = TestFixtures.video1.settingWatched(true)
        }
        await store.receive(\.setWatchedResult) {
            $0.videos[id: TestFixtures.video1.id] = TestFixtures.video1.settingWatched(false)
            $0.alert = .failure(String.localised("video.setWatchedFailed", table: .videos))
        }
    }

    // MARK: - Server actions

    @Test func unsubscribeTellsTheParent() async {
        var initialState = makeState()
        initialState.alert = AlertState { TextState("Unsubscribe") }
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.channelService.deleteChannel = { _, _ in }
        }

        await store.send(.alert(.presented(.confirmUnsubscribe))) {
            $0.alert = nil
        }
        await store.receive(\.unsubscribeResult)
        await store.receive(\.delegate, .didUnsubscribe(TestFixtures.channel1.channelId))
    }

    @Test func unsubscribeFailureShowsAnAlert() async {
        let store = TestStore(initialState: makeState()) {
            ChannelDetailReducer()
        }

        await store.send(.unsubscribeResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.alert = .failure(String.localised("channel.unsubscribeFailed", table: .login))
        }
    }

    @Test func deleteFromServerFailureShowsAnAlert() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1]
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.deleteVideo = { _, _ in throw NSError(domain: "test", code: 0) }
        }

        await store.send(.view(.deleteFromServerTapped(TestFixtures.video1)))
        await store.receive(\.deleteVideoResult.failure) {
            $0.alert = .failure(String.localised("video.deleteFailed", table: .videos))
        }
    }

    // MARK: - Filter

    /// The server does the filtering, so a channel whose newest videos are
    /// all watched still finds the unwatched ones further back.
    @Test func filterChangeRefetchesFromTheServer() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1]
        initialState.hasLoadedVideos = true
        initialState.currentPage = 2
        initialState.lastPage = 3

        let watchValues = LockIsolated<[String?]>([])
        let watchedPage = PaginatedResponse<VideoResponse>(
            data: [TestFixtures.watchedVideo],
            paginate: TestFixtures.paginatedVideos.paginate
        )
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, watch, _, _ in
                watchValues.withValue { $0.append(watch) }
                return watchedPage
            }
        }

        await store.send(.view(.videoFilterChanged(.watched))) {
            $0.videoFilter = .watched
            $0.videos = []
            $0.currentPage = 1
            $0.lastPage = 1
            $0.hasLoadedVideos = false
            $0.isLoadingVideos = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.watchedVideo]
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
        #expect(watchValues.value == ["watched"])
    }

    @Test func filterSendsTheServersWatchValue() {
        #expect(ChannelVideoFilter.unwatched.apiValue == "unwatched")
        #expect(ChannelVideoFilter.inProgress.apiValue == "continue")
        #expect(ChannelVideoFilter.watched.apiValue == "watched")
        #expect(ChannelVideoFilter.all.apiValue == nil)
    }

    /// Marking a video watched under Unwatched takes it out of the list
    /// without waiting for a refetch.
    @Test func videoMarkedWatchedLeavesTheUnwatchedList() {
        var state = makeState()
        state.videos = [TestFixtures.video1, TestFixtures.video2]
        state.videos[id: TestFixtures.video1.id] = TestFixtures.video1.settingWatched(true)

        #expect(state.filteredVideos.ids == [TestFixtures.video2.id])
    }

    // MARK: - Multi-select

    @Test func tappingACardWhileSelectingPicksItInsteadOfPlaying() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1, TestFixtures.video2]
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.view(.selectTapped)) {
            $0.isSelecting = true
        }
        await store.send(.view(.videoCardTapped(TestFixtures.video1))) {
            $0.selectedVideoIDs = [TestFixtures.video1.videoId]
        }
        await store.send(.view(.videoCardTapped(TestFixtures.video1))) {
            $0.selectedVideoIDs = []
        }
        await store.send(.view(.doneSelectingTapped)) {
            $0.isSelecting = false
        }
    }

    @Test func selectAllTogglesEveryShownVideo() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1, TestFixtures.video2]
        initialState.isSelecting = true
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.view(.selectAllTapped)) {
            $0.selectedVideoIDs = [TestFixtures.video1.videoId, TestFixtures.video2.videoId]
        }
        await store.send(.view(.selectAllTapped)) {
            $0.selectedVideoIDs = []
        }
    }

    @Test func markSelectedWatchedFlipsEachAndEndsSelection() async {
        var initialState = makeState()
        initialState.videoFilter = .all
        initialState.videos = [TestFixtures.video1, TestFixtures.video2]
        initialState.isSelecting = true
        initialState.selectedVideoIDs = [TestFixtures.video1.videoId, TestFixtures.video2.videoId]
        let calls = LockIsolated<Set<String>>([])
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, videoId, isWatched in
                #expect(isWatched)
                calls.withValue { _ = $0.insert(videoId) }
            }
        }

        await store.send(.view(.markSelectedWatchedTapped)) {
            $0.isSelecting = false
            $0.selectedVideoIDs = []
            $0.videos = [
                TestFixtures.video1.settingWatched(true),
                TestFixtures.video2.settingWatched(true),
            ]
        }
        await store.receive(\.setWatchedResult)
        await store.receive(\.setWatchedResult)
        #expect(calls.value == [TestFixtures.video1.videoId, TestFixtures.video2.videoId])
    }

    @Test func deleteSelectedConfirmsThenDeletesFromTheServer() async {
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1, TestFixtures.video2]
        initialState.isSelecting = true
        initialState.selectedVideoIDs = [TestFixtures.video2.videoId]
        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.deleteVideo = { _, _ in }
        }

        await store.send(.view(.deleteSelectedTapped)) {
            $0.alert = .confirmDelete(count: 1, action: .confirmDeleteSelected)
        }
        await store.send(.alert(.presented(.confirmDeleteSelected))) {
            $0.alert = nil
            $0.isSelecting = false
            $0.selectedVideoIDs = []
        }
        await store.receive(\.deleteVideoResult.success) {
            $0.videos = [TestFixtures.video1]
        }
    }
}
