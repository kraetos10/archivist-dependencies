import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct LoginReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        /// The server entered on the previous screen. A plain value: login
        /// only reads it, and the parent keeps its own copy.
        var registrationDetails: RegistrationDetails
        var apiToken = ""
        var isLoading = false
        /// Set once the user confirms their server runs with
        /// `DISABLE_STATIC_AUTH=true`, so a retry after a failed login
        /// doesn't ask again.
        var hasConfirmedStaticAuthDisabled = false
        @Presents var alert: AlertState<AlertAction>?

        /// The server setting the app needs, shown verbatim — it's an
        /// environment variable, so it's never translated.
        let staticAuthVariable = "DISABLE_STATIC_AUTH=true"

        public init(registrationDetails: RegistrationDetails) {
            self.registrationDetails = registrationDetails
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
        case staticAuthDisabledConfirmed
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case binding(BindingAction<State>)
        case loginSucceeded(String)
        case pingResult(Result<Void, Error>)

        @CasePathable
        public enum View {
            case loginButtonTapped
        }
    }

    @Dependency(\.pingService) var pingService

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .alert(.presented(.staticAuthDisabledConfirmed)):
                return handleStaticAuthDisabledConfirmed(state: &state)
            case .pingResult(let result):
                return handlePingResult(result, state: &state)
            case .alert, .loginSucceeded, .binding:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
