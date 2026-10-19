#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct DiscoverSetupReducerTests {
    private func withKey(_ key: String) -> DiscoverSetupReducer.State {
        var state = DiscoverSetupReducer.State()
        state.keyInput = key
        return state
    }

    @Test func stepsAdvanceAndGoBack() async {
        let store = TestStore(initialState: DiscoverSetupReducer.State()) {
            DiscoverSetupReducer()
        }

        await store.send(.view(.nextTapped)) { $0.step = .project }
        await store.send(.view(.nextTapped)) { $0.step = .enableAPI }
        await store.send(.view(.backTapped)) { $0.step = .project }
    }

    @Test func aRejectedKeyOpensOnThePasteStep() {
        let state = DiscoverSetupReducer.State(wasKeyRejected: true)
        #expect(state.step == .paste)
        #expect(state.wasKeyRejected)
    }

    @Test func aGoodKeyIsSavedAndReported() async {
        let keyStore = YouTubeAPIKeyStore.inMemory()
        let store = TestStore(initialState: DiscoverSetupReducer.State()) {
            DiscoverSetupReducer()
        } withDependencies: {
            $0.youTubeAPIKeyStore = keyStore
            $0.youTubeSearchService.validateKey = { _ in }
        }

        await store.send(.view(.pasted("  AIzaKey \n"))) { $0.keyInput = "AIzaKey" }
        await store.send(.view(.verifyTapped)) { $0.isVerifying = true }
        await store.receive(\.verifyResult) { $0.isVerifying = false }
        await store.receive(\.delegate.keySaved)
        #expect(keyStore.load() == "AIzaKey")
    }

    @Test func aKeyOverQuotaIsStillSaved() async {
        let keyStore = YouTubeAPIKeyStore.inMemory()
        let store = TestStore(initialState: withKey("AIzaKey")) {
            DiscoverSetupReducer()
        } withDependencies: {
            $0.youTubeAPIKeyStore = keyStore
            $0.youTubeSearchService.validateKey = { _ in throw YouTubeError.quotaExceeded }
        }

        await store.send(.view(.verifyTapped)) { $0.isVerifying = true }
        await store.receive(\.verifyResult) { $0.isVerifying = false }
        await store.receive(\.delegate.keySaved)
        #expect(keyStore.load() == "AIzaKey")
    }

    @Test(arguments: [
        (YouTubeError.invalidKey, DiscoverSetupReducer.State.Failure.invalidKey),
        (YouTubeError.apiNotEnabled, DiscoverSetupReducer.State.Failure.apiNotEnabled),
        (YouTubeError.network, DiscoverSetupReducer.State.Failure.network),
        (YouTubeError.rejected("x"), DiscoverSetupReducer.State.Failure.unexpected)
    ])
    func failuresAreShownAndNothingIsSaved(
        error: YouTubeError,
        failure: DiscoverSetupReducer.State.Failure
    ) async {
        let keyStore = YouTubeAPIKeyStore.inMemory()
        let store = TestStore(initialState: withKey("bad")) {
            DiscoverSetupReducer()
        } withDependencies: {
            $0.youTubeAPIKeyStore = keyStore
            $0.youTubeSearchService.validateKey = { _ in throw error }
        }

        await store.send(.view(.verifyTapped)) { $0.isVerifying = true }
        await store.receive(\.verifyResult) {
            $0.isVerifying = false
            $0.failure = failure
        }
        #expect(keyStore.load() == nil)
    }

    @Test func editingTheKeyClearsTheFailure() async {
        var initial = withKey("bad")
        initial.failure = .invalidKey
        let store = TestStore(initialState: initial) {
            DiscoverSetupReducer()
        }

        await store.send(.binding(.set(\.keyInput, "better"))) {
            $0.keyInput = "better"
            $0.failure = nil
        }
    }
}
#endif
