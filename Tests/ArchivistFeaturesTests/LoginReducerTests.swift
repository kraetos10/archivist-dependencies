import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.dependencies, .timeLimit(.minutes(1)))
struct LoginReducerTests {
    private func makeState() -> LoginReducer.State {
        var state = LoginReducer.State(registrationDetails: RegistrationDetails())
        state.apiToken = "token"
        return state
    }

    @Test func loginAsksToConfirmStaticAuthBeforePinging() async {
        let store = TestStore(initialState: makeState()) {
            LoginReducer()
        }

        // No ping yet: pingService is unimplemented in tests, so calling it
        // would fail the test.
        await store.send(.view(.loginButtonTapped)) {
            $0.alert = .confirmStaticAuthDisabled
        }
    }

    @Test func confirmingStaticAuthLogsIn() async {
        let store = TestStore(initialState: makeState()) {
            LoginReducer()
        } withDependencies: {
            $0.pingService.ping = { _ in PingResponse(response: "pong", user: 1, version: nil) }
        }

        await store.send(.view(.loginButtonTapped)) {
            $0.alert = .confirmStaticAuthDisabled
        }
        await store.send(.alert(.presented(.staticAuthDisabledConfirmed))) {
            $0.alert = nil
            $0.hasConfirmedStaticAuthDisabled = true
            $0.isLoading = true
        }
        await store.receive(\.pingResult) {
            $0.isLoading = false
        }
        await store.receive(\.loginSucceeded)
    }

    @Test func cancellingTheConfirmationDoesNotLogIn() async {
        let store = TestStore(initialState: makeState()) {
            LoginReducer()
        }

        await store.send(.view(.loginButtonTapped)) {
            $0.alert = .confirmStaticAuthDisabled
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    @Test func retryAfterConfirmingDoesNotAskAgain() async {
        var state = makeState()
        state.hasConfirmedStaticAuthDisabled = true
        let store = TestStore(initialState: state) {
            LoginReducer()
        } withDependencies: {
            $0.pingService.ping = { _ in PingResponse(response: "pong", user: 1, version: nil) }
        }

        await store.send(.view(.loginButtonTapped)) {
            $0.isLoading = true
        }
        await store.receive(\.pingResult) {
            $0.isLoading = false
        }
        await store.receive(\.loginSucceeded)
    }

    @Test func rejectedKeyShowsInvalidKeyAlert() async {
        var state = makeState()
        state.hasConfirmedStaticAuthDisabled = true
        let store = TestStore(initialState: state) {
            LoginReducer()
        } withDependencies: {
            $0.pingService.ping = { _ in throw NetworkingError.errorStatusCode(401, "") }
        }

        await store.send(.view(.loginButtonTapped)) {
            $0.isLoading = true
        }
        await store.receive(\.pingResult) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState(String.localised("login.loginFailed", table: .login))
            } message: {
                TextState(String.localised("login.invalidApiKey", table: .login))
            }
        }
    }

    @Test func unreachableServerShowsConnectionAlert() async {
        var state = makeState()
        state.hasConfirmedStaticAuthDisabled = true
        let store = TestStore(initialState: state) {
            LoginReducer()
        } withDependencies: {
            $0.pingService.ping = { _ in throw URLError(.notConnectedToInternet) }
        }

        await store.send(.view(.loginButtonTapped)) {
            $0.isLoading = true
        }
        await store.receive(\.pingResult) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState(String.localised("login.couldNotConnect", table: .login))
            } message: {
                TextState(String.localised("login.checkDetails", table: .login))
            }
        }
    }

    @Test func tokenIsTrimmedBeforeLoggingIn() async {
        var state = makeState()
        state.apiToken = "  token \n"
        state.hasConfirmedStaticAuthDisabled = true
        let store = TestStore(initialState: state) {
            LoginReducer()
        } withDependencies: {
            $0.pingService.ping = { config in
                #expect(config.apiToken == "token")
                return PingResponse(response: "pong", user: 1, version: nil)
            }
        }

        await store.send(.view(.loginButtonTapped)) {
            $0.apiToken = "token"
            $0.isLoading = true
        }
        await store.receive(\.pingResult) {
            $0.isLoading = false
        }
        await store.receive(\.loginSucceeded)
    }

    @Test func repeatPressWhileLoadingIsIgnored() async {
        var state = makeState()
        state.isLoading = true
        state.hasConfirmedStaticAuthDisabled = true
        let store = TestStore(initialState: state) {
            LoginReducer()
        }

        await store.send(.view(.loginButtonTapped))
    }
}
