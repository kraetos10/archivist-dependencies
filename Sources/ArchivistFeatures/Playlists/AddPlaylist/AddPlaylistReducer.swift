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
        /// Set while child mode's PIN sheet is up. Carries the PIN to check
        /// and which action runs once it's confirmed.
        var pinRequest: ChildModePinRequest?
        @Shared(.childModeEnabled) var childModeEnabled
        @Presents var alert: AlertState<AlertAction>?

        var trimmedPlaylistInput: String {
            playlistInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var trimmedCustomName: String {
            customName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canSubscribe: Bool {
            !trimmedPlaylistInput.isEmpty && !isSubscribing
        }

        var canCreateCustom: Bool {
            !trimmedCustomName.isEmpty && !isSubscribing
        }
    }

    public enum AlertAction: Equatable, Sendable {}

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case subscribeResult(Result<Void, Error>)
        case createCustomResult(Result<Void, Error>)

        @CasePathable
        public enum View {
            case addButtonTapped
            case createCustomTapped
            case pinConfirmed
            case pinCancelled
        }

        public enum Delegate: Equatable, Sendable {
            /// A playlist was subscribed to or created.
            case didAdd
        }
    }

    @Dependency(\.playlistService) var playlistService
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
            case .subscribeResult, .createCustomResult:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
