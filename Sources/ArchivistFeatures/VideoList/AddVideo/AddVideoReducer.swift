import ArchivistComponents
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
        var fastAdd = false
        var reDownload = false
        var autoDownload = false
        var isAdding = false
        var isPresentingPin = false
        @Shared(.appStorage(ChildMode.enabledKey)) public var childModeEnabled = false
        @Shared(.appStorage(ChildMode.pinKey)) public var childModePin = ""
    }

    public enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case addResult(Result<Void, Error>)
        case pinConfirmed
        case pinCancelled

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
            case .pinConfirmed:
                state.isPresentingPin = false
                return performAdd(state: &state)
            case .pinCancelled:
                state.isPresentingPin = false
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
