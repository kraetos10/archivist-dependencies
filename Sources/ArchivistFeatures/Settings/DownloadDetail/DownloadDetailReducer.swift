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
        @Shared(.childModeEnabled) public var childModeEnabled
        @Presents var pinEntry: PinEntryReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        var thumbURL: URL? {
            download.thumbURL(config: serverConfig)
        }

        var youtubeURL: URL? {
            download.youtubeURL
        }

        var displayTitle: String {
            download.title ?? download.youtubeId
        }

        /// The download button spins from the tap until the screen closes.
        var isDownloadBusy: Bool {
            isDownloading || downloadTriggered
        }

        init(
            serverConfig: ServerConfig,
            download: DownloadResponse
        ) {
            self.serverConfig = serverConfig
            self.download = download
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case downloadResult(Result<Void, Error>)
        case deleteResult(Result<Void, Error>)
        case pinEntry(PresentationAction<PinEntryReducer.Action>)
        case pinLoaded(String?)
        case delegate(Delegate)

        @CasePathable
        public enum View {
            case downloadTapped
            case deleteTapped
        }

        public enum Delegate: Equatable, Sendable {
            /// The video was bumped to the front of the server queue. The
            /// screen dismisses itself straight after.
            case didQueueDownload(String)
            /// The video was removed from the server queue. The screen
            /// dismisses itself straight after.
            case didDelete(String)
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.pinStore) var pinStore

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .pinLoaded(let pin):
                return handlePinLoaded(pin, state: &state)
            case .pinEntry(.presented(.succeeded)):
                state.pinEntry = nil
                return performDownload(state: &state)
            case .pinEntry:
                return .none
            case .downloadResult(let result):
                return handleDownloadResult(result, state: &state)
            case .deleteResult(let result):
                return handleDeleteResult(result, state: &state)
            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$pinEntry, action: \.pinEntry) {
            PinEntryReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
