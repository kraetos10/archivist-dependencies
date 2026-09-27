#if os(iOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

/// The mini-player tests drive a plain `Store` and check what reached the
/// player and the server; the child-mode tests assert state exhaustively.
@MainActor
@Suite(
    .serialized,
    .timeLimit(.minutes(1)),
    .dependencies {
        try $0.bootstrapInMemoryDatabase()
        $0.playerClient = .noop
    }
)
struct TabReducerTests {
    let config = TestFixtures.serverConfig

    private func stateWithMiniPlayer() -> TabReducer.State {
        var state = TabReducer.State(serverConfig: config)
        var detail = VideoDetailReducer.State(serverConfig: config, video: TestFixtures.video1)
        detail.isHostedInMiniPlayer = true
        detail.isMiniPlayerCollapsed = true
        state.miniPlayer = detail
        return state
    }

    // MARK: - Mini player

    @Test func closingTheMiniPlayerSavesThePositionReadAtStop() async {
        let saved = LockIsolated<(String, Int)?>(nil)
        let roles = LockIsolated<[PlayerSurfaceRole]>([])
        let store = Store(initialState: stateWithMiniPlayer()) {
            TabReducer()
        } withDependencies: {
            $0.playerClient.stopReturningPosition = { _ in 42 }
            $0.playerClient.setActivePlayerSurfaceRole = { role in roles.withValue { $0.append(role) } }
            $0.videoService.setProgress = { _, videoId, position in
                saved.setValue((videoId, position))
            }
        }

        await store.send(.miniPlayerCloseTapped).finish()

        #expect(store.miniPlayer == nil)
        #expect(saved.value?.0 == TestFixtures.video1.videoId)
        #expect(saved.value?.1 == 42)
        #expect(roles.value == [.fullDetail])
    }

    @Test func reopeningTheSameVideoHandsPlaybackOverWithoutStopping() async {
        let stopped = LockIsolated(false)
        let roles = LockIsolated<[PlayerSurfaceRole]>([])
        let store = Store(initialState: stateWithMiniPlayer()) {
            TabReducer()
        } withDependencies: {
            $0.playerClient.stopReturningPosition = { _ in
                stopped.setValue(true)
                return 0
            }
            $0.playerClient.setActivePlayerSurfaceRole = { role in roles.withValue { $0.append(role) } }
        }

        await store.send(.miniPlayerRequested(.detailAppeared(videoId: TestFixtures.video1.videoId))).finish()

        #expect(store.miniPlayer == nil)
        #expect(stopped.value == false)
        #expect(roles.value == [.fullDetail])
    }

    @Test func anotherVideoOpeningStopsTheMiniPlayer() async {
        let stopped = LockIsolated(false)
        let store = Store(initialState: stateWithMiniPlayer()) {
            TabReducer()
        } withDependencies: {
            $0.playerClient.stopReturningPosition = { _ in
                stopped.setValue(true)
                return 0
            }
        }

        await store.send(.miniPlayerRequested(.detailAppeared(videoId: "some_other_video"))).finish()

        #expect(store.miniPlayer == nil)
        #expect(stopped.value)
    }

    // MARK: - Child mode

    @Test func settingsAsksForThePinInChildMode() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: TabReducer.State(serverConfig: config)) {
            TabReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("1234")
        }

        await store.send(.selectTab(.settings)) {
            $0.selectedTab = .settings
        }
        await store.receive(\.settingsPinLoaded) {
            $0.settingsPin = PinEntryReducer.State(expectedPin: "1234")
        }
        await store.send(.settingsPin(.presented(.succeeded))) {
            $0.settingsUnlocked = true
            $0.settingsPin = nil
        }
    }

    @Test func cancellingThePinReturnsHome() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: TabReducer.State(serverConfig: config)) {
            TabReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("1234")
        }

        await store.send(.selectTab(.settings)) {
            $0.selectedTab = .settings
        }
        await store.receive(\.settingsPinLoaded) {
            $0.settingsPin = PinEntryReducer.State(expectedPin: "1234")
        }
        await store.send(.settingsPin(.presented(.cancelled))) {
            $0.settingsPin = nil
            $0.selectedTab = .home
        }
    }

    @Test func childModeWithoutAPinUnlocksSettings() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: TabReducer.State(serverConfig: config)) {
            TabReducer()
        } withDependencies: {
            $0.pinStore = .inMemory()
        }

        await store.send(.selectTab(.settings)) {
            $0.selectedTab = .settings
        }
        await store.receive(\.settingsPinLoaded) {
            $0.settingsUnlocked = true
        }
    }

    // MARK: - Deep links

    @Test func openVideoOnHomePresentsTheVideo() {
        var state = TabReducer.State(serverConfig: config)
        state.selectedTab = .channels

        state.openVideoOnHome(TestFixtures.video1)

        #expect(state.selectedTab == .home)
        #expect(state.videoList.destination?.videoDetail?.video.videoId == TestFixtures.video1.videoId)
    }
}
#endif
