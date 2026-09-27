import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct ChannelsAddChannelReducerTests {
    let config = TestFixtures.serverConfig

    private func makeState(input: String = "UC_new") -> AddChannelReducer.State {
        var state = AddChannelReducer.State(serverConfig: config)
        state.channelInput = input
        return state
    }

    @Test func subscribingTellsTheParentThenDismisses() async {
        let dismissed = LockIsolated(false)
        let subscribed = LockIsolated<[String]>([])
        let store = TestStore(initialState: makeState(input: "  UC_new  ")) {
            AddChannelReducer()
        } withDependencies: {
            $0.channelService.subscribeChannels = { _, items in
                subscribed.withValue { $0 = items.map(\.channelId) }
            }
            $0.pinStore = .inMemory()
        }
        store.dependencies.dismiss = DismissEffect { dismissed.setValue(true) }

        await store.send(.view(.addButtonTapped)) {
            $0.isSubscribing = true
        }
        await store.receive(\.subscribeResult) {
            $0.isSubscribing = false
        }
        await store.receive(\.delegate, .didSubscribe)
        #expect(subscribed.value == ["UC_new"])
        #expect(dismissed.value)
    }

    @Test func blankInputDoesNothing() async {
        let store = TestStore(initialState: makeState(input: "   ")) {
            AddChannelReducer()
        }

        await store.send(.view(.addButtonTapped))
    }

    @Test func subscribeFailureShowsAnAlertAndStaysOpen() async {
        let store = TestStore(initialState: makeState()) {
            AddChannelReducer()
        } withDependencies: {
            $0.channelService.subscribeChannels = { _, _ in throw NSError(domain: "test", code: 0) }
            $0.pinStore = .inMemory()
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isSubscribing = true
        }
        await store.receive(\.subscribeResult) {
            $0.isSubscribing = false
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(String.localised("channel.subscribeFailed", table: .login))
            }
        }
    }

    @Test func childModeAsksForThePinFirst() async {
        var initialState = makeState()
        initialState.$childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: initialState) {
            AddChannelReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("1234")
            $0.channelService.subscribeChannels = { _, _ in }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.view(.addButtonTapped)) {
            $0.pinRequest = ChildModePinRequest(expectedPin: "1234", purpose: .subscribe)
        }
        await store.send(.view(.pinConfirmed)) {
            $0.pinRequest = nil
            $0.isSubscribing = true
        }
        await store.receive(\.subscribeResult) {
            $0.isSubscribing = false
        }
        await store.receive(\.delegate, .didSubscribe)
        store.state.$childModeEnabled.withLock { $0 = false }
    }

    @Test func cancellingThePinSubscribesNothing() async {
        var initialState = makeState()
        initialState.$childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: initialState) {
            AddChannelReducer()
        } withDependencies: {
            $0.pinStore = .inMemory("1234")
        }

        await store.send(.view(.addButtonTapped)) {
            $0.pinRequest = ChildModePinRequest(expectedPin: "1234", purpose: .subscribe)
        }
        await store.send(.view(.pinCancelled)) {
            $0.pinRequest = nil
        }
        store.state.$childModeEnabled.withLock { $0 = false }
    }

    @Test func childModeWithoutAPinSubscribesDirectly() async {
        var initialState = makeState()
        initialState.$childModeEnabled.withLock { $0 = true }
        let store = TestStore(initialState: initialState) {
            AddChannelReducer()
        } withDependencies: {
            $0.pinStore = .inMemory()
            $0.channelService.subscribeChannels = { _, _ in }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.view(.addButtonTapped)) {
            $0.isSubscribing = true
        }
        await store.receive(\.subscribeResult) {
            $0.isSubscribing = false
        }
        await store.receive(\.delegate, .didSubscribe)
        store.state.$childModeEnabled.withLock { $0 = false }
    }
}
