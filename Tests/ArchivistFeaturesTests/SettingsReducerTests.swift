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
        // Video detail state observes the device-download table.
        try $0.bootstrapInMemoryDatabase()
    }
)
struct SettingsReducerTests {
    let config = TestFixtures.serverConfig

    @Test func autoPlayTogglesPersist() async {
        let store = TestStore(initialState: SettingsReducer.State(serverConfig: config)) {
            SettingsReducer()
        }

        await store.send(.view(.autoPlayToggled(false))) {
            $0.$autoPlayEnabled.withLock { $0 = false }
        }
        await store.send(.view(.autoPlayPlaylistToggled(false))) {
            $0.$autoPlayPlaylist.withLock { $0 = false }
        }
    }

    @Test func failedRescanShowsAlert() async {
        let failure = URLError(.timedOut)
        let store = TestStore(initialState: SettingsReducer.State(serverConfig: config)) {
            SettingsReducer()
        } withDependencies: {
            $0.taskService.startTask = { _, _ in throw failure }
        }

        await store.send(.view(.rescanSubscriptionsTapped)) {
            $0.isRescanningSubscriptions = true
        }
        await store.receive(\.rescanSubscriptionsResult) {
            $0.isRescanningSubscriptions = false
            $0.alert = AlertState {
                TextState(String.localised("settings.rescanFailed", table: .settings))
            } message: {
                TextState(failure.localizedDescription)
            }
        }
    }

    @Test func finishedDownloadRefreshesTheQueueScreen() async throws {
        var state = SettingsReducer.State(serverConfig: config)
        state.path.append(.downloads(DownloadsReducer.State(serverConfig: config)))
        state.path.append(.stats(StatsReducer.State(serverConfig: config)))
        let store = TestStore(initialState: state) {
            SettingsReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, page, _, _, _, _ in
                #expect(page == 1)
                return TestFixtures.emptyDownloads
            }
        }
        let downloadsID = try #require(store.state.path.ids.first)

        await store.send(.activeTask(.downloadCompleted))
        await store.receive(\.path) {
            $0.path[id: downloadsID, case: \.downloads]?.isLoading = true
        }
        await store.receive(\.path) {
            $0.path[id: downloadsID, case: \.downloads]?.isLoading = false
            $0.path[id: downloadsID, case: \.downloads]?.hasLoaded = true
        }
    }

    @Test func diagnosticsLogCanBeLoadedAndCleared() async {
        let logURL = URL(filePath: "/tmp/vlc.log")
        let cleared = LockIsolated(false)
        let store = TestStore(initialState: SettingsReducer.State(serverConfig: config)) {
            SettingsReducer()
        } withDependencies: {
            $0.diagnosticsLog = DiagnosticsLogClient(
                logFileURL: { logURL },
                clear: { cleared.setValue(true) }
            )
        }

        await store.send(.view(.viewDidAppear))
        await store.receive(\.diagnosticLogLoaded) {
            $0.diagnosticLogURL = logURL
        }
        await store.send(.view(.clearDiagnosticLogsTapped)) {
            $0.diagnosticLogURL = nil
        }
        await store.finish()
        #expect(cleared.value)
    }

    @Test func historySelectionOpensTheVideoWithTheAutoplaySetting() async throws {
        @Shared(.autoPlayEnabled) var autoPlayEnabled
        $autoPlayEnabled.withLock { $0 = false }
        var state = SettingsReducer.State(serverConfig: config)
        state.path.append(.history(HistoryReducer.State(serverConfig: config)))
        let store = TestStore(initialState: state) {
            SettingsReducer()
        }
        let historyID = try #require(store.state.path.ids.first)

        await store.send(
            .path(.element(id: historyID, action: .history(.delegate(.videoSelected(TestFixtures.video1)))))
        ) {
            $0.videoDetail = VideoDetailReducer.State(
                serverConfig: config,
                video: TestFixtures.video1,
                nextVideos: [],
                shouldAutoPlayNextVideo: false
            )
        }
    }
}
