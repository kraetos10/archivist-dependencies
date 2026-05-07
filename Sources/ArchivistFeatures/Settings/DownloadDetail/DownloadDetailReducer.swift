import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct DownloadDetailReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var download: DownloadResponse
        var isDownloading = false
        var downloadTriggered = false
        var isDeleting = false
        var isPresentingDownloadPin = false
        @Shared(.appStorage(ChildMode.enabledKey)) public var childModeEnabled = false
        @Shared(.appStorage(ChildMode.pinKey)) public var childModePin = ""

        var thumbURL: URL? {
            download.thumbURL(config: serverConfig)
        }

        var youtubeURL: URL? {
            download.youtubeURL
        }
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case downloadResult(Result<Void, Error>)
        case performDelete
        case deleteResult(Result<Void, Error>)
        case pinDownloadConfirmed
        case pinDownloadCancelled

        @CasePathable
        public enum View {
            case viewDidAppear
            case dismissTapped
            case downloadTapped
            case deleteTapped
        }
    }

    @Dependency(\.downloadService) var downloadService

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .pinDownloadConfirmed:
                state.isPresentingDownloadPin = false
                return performDownload(state: &state)
            case .pinDownloadCancelled:
                state.isPresentingDownloadPin = false
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }

}
