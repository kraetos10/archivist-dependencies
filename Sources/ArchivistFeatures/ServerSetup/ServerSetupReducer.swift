import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

@Reducer
public struct ServerSetupReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var path = StackState<ServerSetupPath.State>()
        var registrationDetails = RegistrationDetails()
        var isLoading = false
        /// The switch's position. Starts where child mode actually is, and
        /// only settles `childModeEnabled` once a PIN is saved (or cleared).
        var childModeToggle = false
        @Shared(.childModeEnabled) public var childModeEnabled
        @Presents var pinSetup: ChildPinSetupReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        public init() {
            childModeToggle = childModeEnabled
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case binding(BindingAction<State>)
        case childModeSaveResult(Result<Bool, Error>)
        case healthCheckResult(Result<Void, Error>)
        /// Sent once the connection and token are stored. Carries the
        /// config so the parent doesn't read it back from the database.
        case loginCompleted(ServerConfig)
        case loginSaveFailed
        case path(StackActionOf<ServerSetupPath>)
        case pinSetup(PresentationAction<ChildPinSetupReducer.Action>)

        @CasePathable
        public enum View {
            case nextButtonTapped
        }
    }

    @Dependency(\.defaultDatabase) var database
    @Dependency(\.healthService) var healthService
    @Dependency(\.keychainService) var keychainService
    @Dependency(\.localNetworkPrompt) var localNetworkPrompt
    @Dependency(\.pinStore) var pinStore

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .binding(\.childModeToggle):
                return handleChildModeToggled(state: &state)
            case .pinSetup(.presented(.confirmed(let pin))):
                return handleChildPinConfirmed(pin, state: &state)
            case .pinSetup(.presented(.cancelled)), .pinSetup(.dismiss):
                state.pinSetup = nil
                state.childModeToggle = state.childModeEnabled
                return .none
            case .childModeSaveResult(let result):
                return handleChildModeSaveResult(result, state: &state)
            case .healthCheckResult(let result):
                return handleHealthCheckResult(result, state: &state)
            case .path(.element(_, action: .login(.loginSucceeded(let token)))):
                return handleLoginSucceeded(token: token, state: &state)
            case .loginSaveFailed:
                state.alert = .loginSaveFailed
                return .none
            case .alert, .binding, .loginCompleted, .path, .pinSetup:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$pinSetup, action: \.pinSetup) {
            ChildPinSetupReducer()
        }
        .forEach(\.path, action: \.path)
    }
}
