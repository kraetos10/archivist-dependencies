import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Security
import SQLiteData
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(
    .serialized,
    .timeLimit(.minutes(1)),
    .dependencies {
        try $0.bootstrapInMemoryDatabase()
        $0.localNetworkPrompt.trigger = {}
    }
)
struct ServerSetupReducerTests {
    private func makeState() -> ServerSetupReducer.State {
        var state = ServerSetupReducer.State()
        state.registrationDetails.serverAddress = "archive.local"
        state.registrationDetails.port = "8000"
        return state
    }

    // MARK: - Server check

    @Test func healthyServerMovesOnToLogin() async {
        let details = makeState().registrationDetails
        let store = TestStore(initialState: makeState()) {
            ServerSetupReducer()
        } withDependencies: {
            $0.healthService.checkHealth = { _, _, _ in }
        }

        await store.send(.view(.nextButtonTapped)) {
            $0.isLoading = true
        }
        await store.receive(\.healthCheckResult) {
            $0.isLoading = false
            $0.path[id: 0] = .login(LoginReducer.State(registrationDetails: details))
        }
    }

    @Test func unreachableServerShowsAlert() async {
        let store = TestStore(initialState: makeState()) {
            ServerSetupReducer()
        } withDependencies: {
            $0.healthService.checkHealth = { _, _, _ in throw URLError(.cannotConnectToHost) }
        }

        await store.send(.view(.nextButtonTapped)) {
            $0.isLoading = true
        }
        await store.receive(\.healthCheckResult) {
            $0.isLoading = false
            $0.alert = .couldNotConnect
        }
    }

    // MARK: - Login

    @Test func successfulLoginCarriesTheConfig() async throws {
        var state = makeState()
        state.path.append(.login(LoginReducer.State(registrationDetails: state.registrationDetails)))
        let savedToken = LockIsolated<String?>(nil)
        let store = TestStore(initialState: state) {
            ServerSetupReducer()
        } withDependencies: {
            $0.keychainService.save = { savedToken.setValue($0) }
        }

        let loginID = try #require(store.state.path.ids.first)
        await store.send(.path(.element(id: loginID, action: .login(.loginSucceeded("api-key")))))
        await store.receive(\.loginCompleted)

        #expect(savedToken.value == "api-key")
        @Dependency(\.defaultDatabase) var database
        let connection = try? await database.read { db in
            try ServerConnection.find(1).fetchOne(db)
        }
        #expect(connection?.serverAddress == "archive.local")
        #expect(connection?.port == "8000")
    }

    @Test func failedSaveShowsAlertInsteadOfCompleting() async throws {
        var state = makeState()
        state.path.append(.login(LoginReducer.State(registrationDetails: state.registrationDetails)))
        let store = TestStore(initialState: state) {
            ServerSetupReducer()
        } withDependencies: {
            $0.keychainService.save = { _ in throw KeychainError.saveFailed(errSecParam) }
        }

        let loginID = try #require(store.state.path.ids.first)
        await store.send(.path(.element(id: loginID, action: .login(.loginSucceeded("api-key")))))
        await store.receive(\.loginSaveFailed) {
            $0.alert = .loginSaveFailed
        }
    }

    // MARK: - Child mode

    @Test func toggleStartsWhereChildModeIs() {
        @Shared(.childModeEnabled) var childModeEnabled
        $childModeEnabled.withLock { $0 = true }

        let state = ServerSetupReducer.State()

        #expect(state.childModeToggle)
    }

    @Test func confirmingAPinTurnsChildModeOn() async {
        let pinStore = PinStore.inMemory()
        let store = TestStore(initialState: makeState()) {
            ServerSetupReducer()
        } withDependencies: {
            $0.pinStore = pinStore
        }

        await store.send(.binding(.set(\.childModeToggle, true))) {
            $0.childModeToggle = true
            $0.pinSetup = ChildPinSetupReducer.State()
        }
        await store.send(.pinSetup(.presented(.confirmed("1234")))) {
            $0.pinSetup = nil
            // The in-memory save finishes inside the send's yield, and
            // `childModeEnabled` is a reference: the flip from the result
            // below is already visible here, so it's asserted here.
            $0.$childModeEnabled.withLock { $0 = true }
        }
        await store.receive(\.childModeSaveResult.success)
        #expect(pinStore.load() == "1234")
    }

    @Test func dismissingPinSetupTurnsTheToggleBackOff() async {
        let store = TestStore(initialState: makeState()) {
            ServerSetupReducer()
        }

        await store.send(.binding(.set(\.childModeToggle, true))) {
            $0.childModeToggle = true
            $0.pinSetup = ChildPinSetupReducer.State()
        }
        await store.send(.pinSetup(.dismiss)) {
            $0.pinSetup = nil
            $0.childModeToggle = false
        }
    }

    @Test func failedPinSaveLeavesChildModeOffAndSaysSo() async {
        let store = TestStore(initialState: makeState()) {
            ServerSetupReducer()
        } withDependencies: {
            $0.pinStore.save = { _ in throw KeychainError.saveFailed(errSecParam) }
        }

        await store.send(.binding(.set(\.childModeToggle, true))) {
            $0.childModeToggle = true
            $0.pinSetup = ChildPinSetupReducer.State()
        }
        await store.send(.pinSetup(.presented(.confirmed("1234")))) {
            $0.pinSetup = nil
        }
        await store.receive(\.childModeSaveResult.failure) {
            $0.childModeToggle = false
            $0.alert = .childModeSaveFailed
        }
    }
}
