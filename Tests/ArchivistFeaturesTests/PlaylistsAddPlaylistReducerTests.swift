import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct PlaylistsAddPlaylistReducerTests {
    let config = TestFixtures.serverConfig

    @Test func subscribingTellsTheParentThenDismisses() async {
        let dismissed = LockIsolated(false)
        var initialState = AddPlaylistReducer.State(serverConfig: config)
        initialState.playlistInput = " PL_new "
        let store = TestStore(initialState: initialState) {
            AddPlaylistReducer()
        } withDependencies: {
            $0.playlistService.subscribePlaylists = { _, items in
                #expect(items.map(\.playlistId) == ["PL_new"])
            }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
            $0.pinStore = .inMemory()
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isSubscribing = true
        }
        await store.receive(\.subscribeResult) {
            $0.isSubscribing = false
        }
        await store.receive(\.delegate, .didAdd)
        #expect(dismissed.value)
    }

    @Test func creatingACustomPlaylistTrimsTheName() async {
        let names = LockIsolated<[String]>([])
        var initialState = AddPlaylistReducer.State(serverConfig: config)
        initialState.mode = .createCustom
        initialState.customName = "  Road trip \n"
        let store = TestStore(initialState: initialState) {
            AddPlaylistReducer()
        } withDependencies: {
            $0.playlistService.createCustomPlaylist = { _, name in
                names.withValue { $0.append(name) }
            }
            $0.dismiss = DismissEffect {}
            $0.pinStore = .inMemory()
        }

        await store.send(.view(.createCustomTapped)) {
            $0.isSubscribing = true
        }
        await store.receive(\.createCustomResult) {
            $0.isSubscribing = false
            $0.customName = ""
        }
        await store.receive(\.delegate, .didAdd)
        #expect(names.value == ["Road trip"])
    }

    @Test func whitespaceOnlyNameCannotBeCreated() async {
        var initialState = AddPlaylistReducer.State(serverConfig: config)
        initialState.customName = "   "
        #expect(!initialState.canCreateCustom)

        let store = TestStore(initialState: initialState) {
            AddPlaylistReducer()
        }
        await store.send(.view(.createCustomTapped))
    }

    /// Creating a playlist in child mode needs the PIN too, not just
    /// subscribing.
    @Test func childModeGuardsCreatingWithThePin() async {
        var initialState = AddPlaylistReducer.State(serverConfig: config)
        initialState.customName = "Mine"
        initialState.$childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: initialState) {
            AddPlaylistReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("4321")
            $0.playlistService.createCustomPlaylist = { _, _ in }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.view(.createCustomTapped)) {
            $0.pinRequest = ChildModePinRequest(expectedPin: "4321", purpose: .createCustom)
        }
        await store.send(.view(.pinConfirmed)) {
            $0.pinRequest = nil
            $0.isSubscribing = true
        }
        await store.receive(\.createCustomResult) {
            $0.isSubscribing = false
            $0.customName = ""
        }
        await store.receive(\.delegate, .didAdd)
        store.state.$childModeEnabled.withLock { $0 = false }
    }

    @Test func childModeGuardsSubscribingWithThePin() async {
        var initialState = AddPlaylistReducer.State(serverConfig: config)
        initialState.playlistInput = "PL_new"
        initialState.$childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: initialState) {
            AddPlaylistReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("4321")
        }

        await store.send(.view(.addButtonTapped)) {
            $0.pinRequest = ChildModePinRequest(expectedPin: "4321", purpose: .subscribe)
        }
        await store.send(.view(.pinCancelled)) {
            $0.pinRequest = nil
        }
        store.state.$childModeEnabled.withLock { $0 = false }
    }

    @Test func createFailureShowsAnAlert() async {
        var initialState = AddPlaylistReducer.State(serverConfig: config)
        initialState.customName = "Mine"
        let store = TestStore(initialState: initialState) {
            AddPlaylistReducer()
        } withDependencies: {
            $0.playlistService.createCustomPlaylist = { _, _ in throw NSError(domain: "test", code: 0) }
            $0.pinStore = .inMemory()
        }

        await store.send(.view(.createCustomTapped)) {
            $0.isSubscribing = true
        }
        await store.receive(\.createCustomResult) {
            $0.isSubscribing = false
            $0.alert = .failure(String.localised("playlist.createFailed", table: .login))
        }
    }
}
