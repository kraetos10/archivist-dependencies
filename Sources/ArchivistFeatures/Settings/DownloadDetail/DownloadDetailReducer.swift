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

        var thumbURL: URL? {
            download.thumbURL(config: serverConfig)
        }

        var youtubeURL: URL {
            download.youtubeURL
        }
    }

    public enum Action: ViewAction {
        case view(View)
        case downloadStarted
        case downloadFailed(Error)
        case performDelete
        case deleteSucceeded
        case deleteFailed(Error)

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
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }

}
