import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

@Reducer
public struct ServerSetupReducer {
    public init() {}
    @ObservableState
    public struct State: Sendable {
        var path = StackState<ServerSetupPath.State>()
        @Shared var registrationDetails: RegistrationDetails
        var isLoading = false
        @Presents var alert: AlertState<AlertAction>?

        public init() {
            _registrationDetails = Shared(value: RegistrationDetails())
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case binding(BindingAction<State>)
        case healthCheckResult(Result<Void, Error>)
        case loginCompleted
        case path(StackActionOf<ServerSetupPath>)
        case serverValidated

        @CasePathable
        public enum View {
            case nextButtonTapped
        }
    }

    @Dependency(\.healthService) var healthService
    @Dependency(\.keychainService) var keychainService
    @Dependency(\.defaultDatabase) var database

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .serverValidated:
                state.path.append(.login(LoginReducer.State(
                    registrationDetails: state.$registrationDetails
                )))
                return .none
            case .path(.element(_, action: .login(.loginSucceeded(let token)))):
                return handleLoginSucceeded(token: token, state: &state)
            case .alert, .binding, .loginCompleted, .path:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .forEach(\.path, action: \.path)
    }

    private func handleLoginSucceeded(
        token: String,
        state: inout State
    ) -> Effect<Action> {
        let details = state.registrationDetails
        return .run { [database, keychainService] send in
            try await database.write { db in
                try ServerConnection
                    .insert {
                        ServerConnection(
                            serverAddress: details.serverAddress,
                            port: details.port,
                            useHTTP: details.useHTTP
                        )
                    } onConflict: {
                        $0.id
                    } doUpdate: { conn, excluded in
                        conn.serverAddress = excluded.serverAddress
                        conn.port = excluded.port
                        conn.useHTTP = excluded.useHTTP
                    }
                    .execute(db)
            }
            try keychainService.save(token: token)
            await send(.loginCompleted)
        }
    }
}
