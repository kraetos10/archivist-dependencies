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
        /// The PIN the child-mode sheet checks against, loaded from the
        /// Keychain when the sheet is raised and cleared when it closes.
        var expectedPin = ""
        @Shared(.childModeEnabled) public var childModeEnabled
        @Presents var alert: AlertState<AlertAction>?

        var trimmedInput: String {
            videoInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canAdd: Bool {
            !trimmedInput.isEmpty && !isAdding
        }

        public init(
            serverConfig: ServerConfig,
            playlistId: String? = nil
        ) {
            self.serverConfig = serverConfig
            self.playlistId = playlistId
        }
    }

    public enum AlertAction: Equatable, Sendable {}

    public enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case addResult(Result<Void, Error>)

        @CasePathable
        public enum View {
            case addButtonTapped
            case pinConfirmed
            case pinCancelled
        }
    }

    @Dependency(\.downloadService) var downloadService
    @Dependency(\.playlistService) var playlistService
    @Dependency(\.pinStore) var pinStore

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .alert:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
