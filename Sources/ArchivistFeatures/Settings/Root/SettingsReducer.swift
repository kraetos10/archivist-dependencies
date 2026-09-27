import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct SettingsReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        public var serverConfig: ServerConfig
        var activeTask: ActiveTaskReducer.State
        var path = StackState<SettingsPath.State>()
        var isRescanningSubscriptions = false
        var supportURL: URL?
        /// The libvlc log, when there's something in it to share.
        var diagnosticLogURL: URL?
        @Shared(.autoPlayEnabled) public var autoPlayEnabled
        @Shared(.autoPlayPlaylist) public var autoPlayPlaylist
        @Presents var videoDetail: VideoDetailReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        var connectionDescription: String {
            serverConfig.useHTTP ? "HTTP" : "HTTPS"
        }

        var portDescription: String? {
            serverConfig.port.map(String.init)
        }

        var isRescanDisabled: Bool {
            isRescanningSubscriptions || activeTask.activeDownload != nil
        }

        /// "1.6 (42)", from the bundle.
        var appVersion: String {
            let info = Bundle.main.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String ?? "?"
            let build = info?["CFBundleVersion"] as? String ?? "?"
            return "\(version) (\(build))"
        }

        public init(
            serverConfig: ServerConfig,
            supportURL: URL? = nil
        ) {
            self.serverConfig = serverConfig
            self.supportURL = supportURL
            self.activeTask = ActiveTaskReducer.State(serverConfig: serverConfig)
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction {
        case view(View)
        case didRequestLogout
        case diagnosticLogLoaded(URL?)
        case rescanSubscriptionsResult(Result<Void, Error>)
        case alert(PresentationAction<AlertAction>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case activeTask(ActiveTaskReducer.Action)
        case path(StackActionOf<SettingsPath>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case autoPlayToggled(Bool)
            case autoPlayPlaylistToggled(Bool)
            case clearDiagnosticLogsTapped
            case logoutTapped
            case rescanSubscriptionsTapped
            case pullToRefreshTriggered
            case downloadsTapped
            case statsTapped
            case historyTapped
            #if !os(tvOS)
            case thirdPartyLibrariesTapped
            #endif
        }
    }

    @Dependency(\.diagnosticsLog) var diagnosticsLog
    @Dependency(\.taskService) var taskService

    public var body: some Reducer<State, Action> {
        Scope(state: \.activeTask, action: \.activeTask) {
            ActiveTaskReducer()
        }
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .videoDetail(.presented(.delegate(.didRequestMinimize))),
                 .videoDetail(.presented(.delegate(.didDismiss))):
                state.videoDetail = nil
                return .none
            case .path(.element(_, action: .history(.delegate(.videoSelected(let video))))):
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: [],
                    shouldAutoPlayNextVideo: state.autoPlayEnabled
                )
                return .none
            case .activeTask(.downloadCompleted):
                return handleDownloadCompleted(state: &state)
            case .diagnosticLogLoaded(let url):
                state.diagnosticLogURL = url
                return .none
            case .rescanSubscriptionsResult(let result):
                return handleRescanResult(result, state: &state)
            case .alert, .activeTask, .didRequestLogout, .path, .videoDetail:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
        .forEach(\.path, action: \.path)
    }
}
