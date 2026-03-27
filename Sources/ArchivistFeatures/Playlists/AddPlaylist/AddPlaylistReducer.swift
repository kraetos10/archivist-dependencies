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
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case subscribeResult(Result<Void, Error>)
        case createCustomResult(Result<Void, Error>)

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
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
