import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct HistoryReducerTests {
    let config = TestFixtures.serverConfig

    /// The regression: "continue watching" finishing first used to clear
    /// the shared loading flag, so the refreshed watched list was appended
    /// to the stale one instead of replacing it.
    @Test func refreshReplacesWatchedEvenWhenContinueFinishesFirst() async {
        var state = HistoryReducer.State(serverConfig: config)
        state.watchedVideos = [TestFixtures.watchedVideo]
        state.hasLoaded = true
        let watchedGate = TestGate()
        let store = TestStore(initialState: state) {
            HistoryReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, watch, _, _ in
                if watch == "watched" {
                    await watchedGate.wait()
                    return TestFixtures.paginatedVideos
                }
                return TestFixtures.emptyVideos
            }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoadingContinue = true
            $0.isLoadingWatched = true
        }
        await store.receive(\.continueVideosResult.success) {
            $0.isLoadingContinue = false
        }
        watchedGate.open()
        await store.receive(\.watchedVideosResult) {
            $0.isLoadingWatched = false
            $0.watchedVideos = IdentifiedArrayOf(uniqueElements: TestFixtures.paginatedVideos.data)
            $0.lastPage = TestFixtures.paginatedVideos.paginate.lastPage
            $0.currentPage = TestFixtures.paginatedVideos.paginate.currentPage
        }
    }

    @Test func laterPagesAppend() async {
        var state = HistoryReducer.State(serverConfig: config)
        state.watchedVideos = [TestFixtures.watchedVideo]
        state.lastPage = 2
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            HistoryReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, page, _, _, _, _, _, _ in
                #expect(page == 2)
                return TestFixtures.paginatedVideosMultiPage(page: 2, lastPage: 2)
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.itemAppeared(TestFixtures.watchedVideo.id))) {
            $0.isLoadingMore = true
        }
        await store.receive(\.watchedVideosResult) {
            $0.isLoadingMore = false
            $0.currentPage = 2
        }
        #expect(store.state.watchedVideos.first?.id == TestFixtures.watchedVideo.id)
        #expect(store.state.watchedVideos.count > 1)
    }

    @Test func selectingAVideoDelegatesIt() async {
        let store = TestStore(initialState: HistoryReducer.State(serverConfig: config)) {
            HistoryReducer()
        }

        await store.send(.view(.videoTapped(TestFixtures.video1)))
        await store.receive(\.delegate, .videoSelected(TestFixtures.video1))
    }
}
