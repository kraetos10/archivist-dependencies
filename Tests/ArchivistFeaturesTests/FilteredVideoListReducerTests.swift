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
    }
)
struct FilteredVideoListReducerTests {
    let config = TestFixtures.serverConfig

    @Test func appearingLoadsTheFirstPageWithTheFiltersQuery() async {
        let store = TestStore(
            initialState: FilteredVideoListReducer.State(serverConfig: config, filter: .unwatched)
        ) {
            FilteredVideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, page, sort, _, _, watch, _, _ in
                #expect(page == 1)
                #expect(sort == VideoSortOrder.published.apiValue)
                #expect(watch == WatchFilter.unwatched.apiValue)
                return TestFixtures.paginatedVideos
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    /// The first page replaces the list even when it isn't empty.
    @Test func pullToRefreshReplacesTheList() async {
        var state = FilteredVideoListReducer.State(serverConfig: config, filter: .all)
        state.videos = [TestFixtures.watchedVideo]
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            FilteredVideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.paginatedVideos }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.videos = []
            $0.hasLoaded = false
            $0.isLoading = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    /// A page thinner than the server's page size pulls the next one
    /// straight away, rather than leaving a sparse grid.
    @Test func aSparsePagePullsTheNextOne() async {
        let store = TestStore(
            initialState: FilteredVideoListReducer.State(serverConfig: config, filter: .all)
        ) {
            FilteredVideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, page, _, _, _, _, _, _ in
                TestFixtures.paginatedVideosMultiPage(page: page, lastPage: 2)
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.lastPage = 2
            $0.isLoading = false
            $0.hasLoaded = true
            $0.isLoadingMore = true
        }
        await store.receive(\.videosResult.success) {
            $0.currentPage = 2
            $0.isLoadingMore = false
        }
    }

    /// Re-sorting cancels a page still loading for the old sort, and the
    /// new sort is stored under this filter's own key.
    @Test func sortChangeCancelsThePageStillLoadingAndPersistsPerFilter() async {
        var state = FilteredVideoListReducer.State(serverConfig: config, filter: .unwatched)
        state.videos = [TestFixtures.video1, TestFixtures.video2]
        state.lastPage = 2
        state.hasLoaded = true
        let staleGate = TestGate()
        let sorts = LockIsolated<[String?]>([])
        let store = TestStore(initialState: state) {
            FilteredVideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, page, sort, _, _, _, _, _ in
                sorts.withValue { $0.append(sort) }
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
        await store.send(.view(.sortOrderChanged(.views))) {
            $0.$sortOrder.withLock { $0 = .views }
            $0.videos = []
            $0.lastPage = 1
            $0.hasLoaded = false
            $0.isLoading = true
            $0.isLoadingMore = false
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.isLoading = false
            $0.hasLoaded = true
        }
        staleGate.open()

        #expect(sorts.value == [VideoSortOrder.published.apiValue, VideoSortOrder.views.apiValue])
        @Shared(.videoListSortOrder(for: .unwatched)) var unwatchedOrder
        @Shared(.videoListSortOrder(for: .watched)) var watchedOrder
        #expect(unwatchedOrder == .views)
        #expect(watchedOrder == .published)
    }

    @Test func choosingTheSameSortDoesNothing() async {
        let store = TestStore(
            initialState: FilteredVideoListReducer.State(serverConfig: config, filter: .all)
        ) {
            FilteredVideoListReducer()
        }

        await store.send(.view(.sortOrderChanged(.published)))
    }

    /// The parent performs the delete but never reports back, so the row
    /// goes straight away.
    @Test func deletingDropsTheRowAndHandsTheWriteUp() async {
        var state = FilteredVideoListReducer.State(serverConfig: config, filter: .all)
        state.videos = [TestFixtures.video1, TestFixtures.video2]
        let store = TestStore(initialState: state) {
            FilteredVideoListReducer()
        }

        await store.send(.view(.deleteFromServerTapped(TestFixtures.video1))) {
            $0.videos.remove(id: TestFixtures.video1.videoId)
        }
        await store.receive(\.delegate, .deleteFromServerRequested(TestFixtures.video1))
    }

    @Test func markingWatchedIsHandedUp() async {
        let store = TestStore(
            initialState: FilteredVideoListReducer.State(serverConfig: config, filter: .all)
        ) {
            FilteredVideoListReducer()
        }

        await store.send(.view(.markAsWatchedTapped(TestFixtures.video1)))
        await store.receive(\.delegate, .markAsWatchedRequested(TestFixtures.video1))
    }

    @Test func aFailedLoadStopsLoading() async {
        let store = TestStore(
            initialState: FilteredVideoListReducer.State(serverConfig: config, filter: .all)
        ) {
            FilteredVideoListReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in throw URLError(.timedOut) }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.videosResult.failure) {
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }
}
