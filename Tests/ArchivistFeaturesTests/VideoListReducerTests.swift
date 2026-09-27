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
}
