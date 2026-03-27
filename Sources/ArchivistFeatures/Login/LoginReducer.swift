import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct LoginReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared var registrationDetails: RegistrationDetails
        var username = ""
        var password = ""
        var isLoading = false
        var pendingToken: String?
        @Presents var alert: AlertState<AlertAction>?

        public init(registrationDetails: Shared<RegistrationDetails>) {
            _registrationDetails = registrationDetails
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case binding(BindingAction<State>)
        case loginCompleted
        case loginFailed(Error)
        case tokenReceived(String)
        case tokenFailed(Error)
        case loginSucceeded(String, username: String, password: String)
        case pingSucceeded
        case pingFailed(Error)

        @CasePathable
        public enum View {
            case loginButtonTapped
        }
    }

    @Dependency(\.userService) var userService
    @Dependency(\.pingService) var pingService

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .alert, .loginSucceeded, .binding:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
