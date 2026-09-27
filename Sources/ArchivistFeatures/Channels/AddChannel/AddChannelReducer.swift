import ArchivistComponents
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
        /// Set while child mode's PIN sheet is up. Carries the PIN to check
        /// against, loaded from the Keychain when the sheet is raised.
        var pinRequest: ChildModePinRequest?
        @Shared(.childModeEnabled) var childModeEnabled
        @Presents var alert: AlertState<AlertAction>?

        var trimmedInput: String {
            channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canSubmit: Bool {
            !trimmedInput.isEmpty && !isSubscribing
        }
    }

    public enum AlertAction: Equatable, Sendable {}

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case subscribeResult(Result<Void, Error>)

        @CasePathable
        public enum View {
            case addButtonTapped
            case pinConfirmed
            case pinCancelled
        }

        public enum Delegate: Equatable, Sendable {
            case didSubscribe
        }
    }

    @Dependency(\.channelService) var channelService
    @Dependency(\.pinStore) var pinStore
    @Dependency(\.dismiss) var dismiss

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .alert, .delegate:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .subscribeResult:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
