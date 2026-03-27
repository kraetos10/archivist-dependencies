import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct AddVideoReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var playlistId: String?
        var videoInput: String = ""
        var isAdding = false
    }

    public enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case addSucceeded
        case addFailed

        @CasePathable
        public enum View {
            case addButtonTapped
        }
    }

    @Dependency(\.downloadService) var downloadService
    @Dependency(\.playlistService) var playlistService

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
