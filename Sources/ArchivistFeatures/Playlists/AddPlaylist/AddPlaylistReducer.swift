import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

enum AddPlaylistMode: String, CaseIterable, Sendable, Equatable {
    case subscribe
    case createCustom
}

@Reducer
public struct AddPlaylistReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var mode: AddPlaylistMode = .subscribe
        var playlistInput: String = ""
        var customName: String = ""
        var isSubscribing: Bool = false
        var isPresentingPin: Bool = false
        @Shared(.appStorage(ChildMode.enabledKey)) public var childModeEnabled = false
        @Shared(.appStorage(ChildMode.pinKey)) public var childModePin = ""
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case subscribeResult(Result<Void, Error>)
        case createCustomResult(Result<Void, Error>)
        case pinConfirmed
        case pinCancelled

        @CasePathable
        public enum View {
            case addButtonTapped
            case createCustomTapped
        }
    }

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
                return performSubscribe(state: &state)
            case .pinCancelled:
                state.isPresentingPin = false
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
