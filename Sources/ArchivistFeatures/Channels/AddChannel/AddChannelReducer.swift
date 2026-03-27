import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct AddChannelReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var channelInput: String = ""
        var isSubscribing: Bool = false
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case subscribeResult(Result<Void, Error>)

        @CasePathable
        public enum View {
            case addButtonTapped
        }
    }

    @Dependency(\.channelService) var channelService

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
