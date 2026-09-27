import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct AddVideoReducerTests {
    let config = TestFixtures.serverConfig

    private func makeState(
        input: String = "  abc123  \n\n def456 ",
        playlistId: String? = nil
    ) -> AddVideoReducer.State {
        var state = AddVideoReducer.State(serverConfig: config, playlistId: playlistId)
        state.videoInput = input
        return state
    }

    @Test func blankInputCantBeAdded() async {
        let state = makeState(input: " \n  ")
        #expect(state.canAdd == false)
        let store = TestStore(initialState: state) {
            AddVideoReducer()
        }

        await store.send(.view(.addButtonTapped))
    }

    @Test func nothingCanBeAddedWhileAnAddIsRunning() {
        var state = makeState()
        #expect(state.canAdd)
        state.isAdding = true
        #expect(state.canAdd == false)
    }

    /// One id per line, trimmed, blank lines dropped, with the form's
    /// options passed through.
    @Test func addingQueuesEveryLine() async {
        let added = LockIsolated<[String]>([])
        let options = LockIsolated<[Bool]>([])
        var state = makeState()
        state.autoDownload = true
        state.reDownload = true
        let store = TestStore(initialState: state) {
            AddVideoReducer()
        } withDependencies: {
            $0.downloadService.addDownloads = { _, items, autostart, flat, force in
                added.setValue(items.map(\.youtubeId))
                options.setValue([autostart, flat, force])
            }
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isAdding = true
        }
        await store.receive(\.addResult) {
            $0.isAdding = false
        }
        #expect(added.value == ["abc123", "def456"])
        #expect(options.value == [true, false, true])
    }

    @Test func addingFromAPlaylistAlsoAddsEachVideoToIt() async {
        let playlistAdds = LockIsolated<[String]>([])
        let store = TestStore(initialState: makeState(playlistId: "PL_custom")) {
            AddVideoReducer()
        } withDependencies: {
            $0.downloadService.addDownloads = { _, _, _, _, _ in }
            $0.playlistService.modifyCustomPlaylist = { _, id, action, videoId, _ in
                playlistAdds.withValue { $0.append("\(id):\(action):\(videoId ?? "")") }
            }
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isAdding = true
        }
        await store.receive(\.addResult) {
            $0.isAdding = false
        }
        #expect(playlistAdds.value == ["PL_custom:create:abc123", "PL_custom:create:def456"])
    }

    @Test func aFailedAddSaysSo() async {
        let failure = URLError(.timedOut)
        let store = TestStore(initialState: makeState()) {
            AddVideoReducer()
        } withDependencies: {
            $0.downloadService.addDownloads = { _, _, _, _, _ in throw failure }
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isAdding = true
        }
        await store.receive(\.addResult) {
            $0.isAdding = false
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(failure.localizedDescription)
            }
        }
    }

    // MARK: - Child mode

    @Test func childModeAsksForThePinFromThePinStore() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let initialState = makeState()
        let store = TestStore(initialState: initialState) {
            AddVideoReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("1234")
            $0.downloadService.addDownloads = { _, _, _, _, _ in }
        }

        await store.send(.view(.addButtonTapped)) {
            $0.expectedPin = "1234"
            $0.isPresentingPin = true
        }
        await store.send(.view(.pinConfirmed)) {
            $0.isPresentingPin = false
            $0.expectedPin = ""
            $0.isAdding = true
        }
        await store.receive(\.addResult) {
            $0.isAdding = false
        }
    }

    @Test func cancellingThePinAddsNothing() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let initialState = makeState()
        let store = TestStore(initialState: initialState) {
            AddVideoReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("1234")
        }

        await store.send(.view(.addButtonTapped)) {
            $0.expectedPin = "1234"
            $0.isPresentingPin = true
        }
        await store.send(.view(.pinCancelled)) {
            $0.isPresentingPin = false
            $0.expectedPin = ""
        }
    }

    @Test func childModeWithoutAPinAddsStraightAway() async {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }
        let initialState = makeState()
        let store = TestStore(initialState: initialState) {
            AddVideoReducer()
        } withDependencies: {
            $0.pinStore = .inMemory()
            $0.downloadService.addDownloads = { _, _, _, _, _ in }
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isAdding = true
        }
        await store.receive(\.addResult) {
            $0.isAdding = false
        }
    }
}
