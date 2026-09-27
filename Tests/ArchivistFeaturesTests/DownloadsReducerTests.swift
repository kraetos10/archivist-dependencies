import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct DownloadsReducerTests {
    let config = TestFixtures.serverConfig

    /// Built before the `TestStore`, never inside its `initialState:`
    /// autoclosure: that runs with shared-change tracking on, so the
    /// sort-order write would be recorded as an unasserted change.
    private func loadedState(sortOrder: DownloadSortOrder = .oldestFirst) -> DownloadsReducer.State {
        var state = DownloadsReducer.State(serverConfig: config)
        state.$sortOrder.withLock { $0 = sortOrder }
        state.downloads = [TestFixtures.download1, TestFixtures.download2]
        state.hasLoaded = true
        return state
    }

    @Test func refreshEntryPointReloadsFromPageOne() async {
        let initialState = loadedState()
        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, page, _, _, _, _ in
                #expect(page == 1)
                return TestFixtures.paginatedDownloads
            }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }
        await store.receive(\.downloadsResult.success) {
            $0.isLoading = false
        }
    }

    @Test func onlyTheLastCardPages() async {
        var state = loadedState()
        state.lastPage = 2
        let store = TestStore(initialState: state) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, page, _, _, _, _ in
                #expect(page == 2)
                return TestFixtures.emptyDownloads
            }
        }

        await store.send(.view(.itemAppeared(TestFixtures.download1.id)))
        await store.send(.view(.itemAppeared(TestFixtures.download2.id))) {
            $0.isLoadingMore = true
        }
        await store.receive(\.downloadsResult.success) {
            $0.isLoadingMore = false
            $0.lastPage = 1
        }
    }

    @Test func sortChangeSupersedesAPageInFlight() async {
        var state = loadedState()
        state.lastPage = 2
        let gate = TestGate()
        let store = TestStore(initialState: state) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, page, _, _, _, _ in
                if page == 2 {
                    // The stale next-page request never returns before the
                    // sort change cancels it.
                    await gate.wait()
                    return TestFixtures.paginatedDownloads
                }
                return TestFixtures.paginatedDownloads
            }
        }

        await store.send(.view(.itemAppeared(TestFixtures.download2.id))) {
            $0.isLoadingMore = true
        }
        await store.send(.view(.sortOrderChanged(.newestFirst))) {
            $0.$sortOrder.withLock { $0 = .newestFirst }
            $0.downloads = []
            $0.lastPage = 1
            $0.isLoading = true
            $0.isLoadingMore = false
            $0.hasLoaded = false
        }
        await store.receive(\.downloadsResult.success) {
            $0.downloads = [TestFixtures.download2, TestFixtures.download1]
            $0.isLoading = false
            $0.hasLoaded = true
        }
        gate.open()
    }

    @Test func failedDeleteKeepsTheRowAndSaysSo() async {
        let failure = URLError(.timedOut)
        let initialState = loadedState()
        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadService.deleteDownload = { _, _ in throw failure }
        }

        await store.send(.view(.deleteTapped(TestFixtures.download1)))
        await store.receive(\.deleteResult) {
            $0.alert = .requestFailed(failure)
        }
    }

    @Test func failedBumpRestoresTheQueueFromTheServer() async {
        let failure = URLError(.timedOut)
        var state = loadedState()
        // The tvOS "Download Now" confirmation is on screen.
        state.alert = AlertState {
            TextState(TestFixtures.download1.title ?? "")
        } actions: {
            ButtonState(action: .confirmDownload(TestFixtures.download1.id)) {
                TextState("Download Now")
            }
        }
        let store = TestStore(initialState: state) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadService.updateDownload = { _, _, _ in throw failure }
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in TestFixtures.paginatedDownloads }
        }

        await store.send(.alert(.presented(.confirmDownload(TestFixtures.download1.id)))) {
            $0.alert = nil
            $0.downloads = [TestFixtures.download2]
            $0.scrollPositionID = TestFixtures.download2.id
            $0.focusedDownloadID = TestFixtures.download2.id
        }
        await store.receive(\.bumpResult) {
            $0.alert = .requestFailed(failure)
            $0.isLoading = true
        }
        await store.receive(\.downloadsResult.success) {
            $0.downloads = [TestFixtures.download1, TestFixtures.download2]
            $0.isLoading = false
        }
    }

    @Test func searchMatchesLocalRowsWithStandardComparison() {
        var state = loadedState()
        state.searchQuery = "pending download 2"

        #expect(state.filteredDownloads.map(\.id) == [TestFixtures.download2.id])
    }
}
