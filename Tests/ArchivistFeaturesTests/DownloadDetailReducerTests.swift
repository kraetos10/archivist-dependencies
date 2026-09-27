import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct DownloadDetailReducerTests {
    let config = TestFixtures.serverConfig
    let download = TestFixtures.download1

    private func makeState() -> DownloadDetailReducer.State {
        DownloadDetailReducer.State(serverConfig: config, download: download)
    }

    @Test func downloadingQueuesTellsThePresenterThenCloses() async {
        let bumped = LockIsolated<[String]>([])
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: makeState()) {
            DownloadDetailReducer()
        } withDependencies: {
            $0.downloadService.updateDownload = { _, id, status in
                bumped.withValue { $0.append("\(id):\(status)") }
            }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.view(.downloadTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadResult) {
            $0.isDownloading = false
            $0.downloadTriggered = true
        }
        await store.receive(\.delegate, .didQueueDownload(download.youtubeId))
        #expect(bumped.value == ["\(download.youtubeId):priority"])
        #expect(dismissed.value)
        // The button stays on its spinner while the screen goes.
        #expect(store.state.isDownloadBusy)
    }

    @Test func aFailedDownloadStaysOpenAndSaysSo() async {
        let failure = URLError(.timedOut)
        let store = TestStore(initialState: makeState()) {
            DownloadDetailReducer()
        } withDependencies: {
            $0.downloadService.updateDownload = { _, _, _ in throw failure }
        }

        await store.send(.view(.downloadTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadResult) {
            $0.isDownloading = false
            $0.alert = .requestFailed(failure)
        }
    }

    @Test func childModeAsksForThePinBeforeDownloading() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let initialState = makeState()
        let store = TestStore(initialState: initialState) {
            DownloadDetailReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("1234")
            $0.downloadService.updateDownload = { _, _, _ in }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.view(.downloadTapped))
        await store.receive(\.pinLoaded) {
            $0.pinEntry = PinEntryReducer.State(expectedPin: "1234")
        }
        await store.send(.pinEntry(.presented(.succeeded))) {
            $0.pinEntry = nil
            $0.isDownloading = true
        }
        await store.receive(\.downloadResult) {
            $0.isDownloading = false
            $0.downloadTriggered = true
        }
        await store.receive(\.delegate, .didQueueDownload(download.youtubeId))
    }

    @Test func childModeWithoutAPinDownloadsStraightAway() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let initialState = makeState()
        let store = TestStore(initialState: initialState) {
            DownloadDetailReducer()
        } withDependencies: {
            $0.pinStore = .inMemory()
            $0.downloadService.updateDownload = { _, _, _ in throw URLError(.timedOut) }
        }

        await store.send(.view(.downloadTapped))
        await store.receive(\.pinLoaded) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadResult) {
            $0.isDownloading = false
            $0.alert = .requestFailed(URLError(.timedOut))
        }
    }

    @Test func deletingTellsThePresenterThenCloses() async {
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: makeState()) {
            DownloadDetailReducer()
        } withDependencies: {
            $0.downloadService.deleteDownload = { _, _ in }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.view(.deleteTapped)) {
            $0.isDeleting = true
        }
        await store.receive(\.deleteResult) {
            $0.isDeleting = false
        }
        await store.receive(\.delegate, .didDelete(download.youtubeId))
        #expect(dismissed.value)
    }

    @Test func aFailedDeleteStaysOpenAndSaysSo() async {
        let failure = URLError(.notConnectedToInternet)
        let store = TestStore(initialState: makeState()) {
            DownloadDetailReducer()
        } withDependencies: {
            $0.downloadService.deleteDownload = { _, _ in throw failure }
        }

        await store.send(.view(.deleteTapped)) {
            $0.isDeleting = true
        }
        await store.receive(\.deleteResult) {
            $0.isDeleting = false
            $0.alert = .requestFailed(failure)
        }
    }
}
