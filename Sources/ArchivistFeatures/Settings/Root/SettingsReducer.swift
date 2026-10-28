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
        /// The community server, linked from the About section.
        let discordURL = URL(string: "https://discord.gg/jUWGnavv8")
        /// The libvlc log, when there's something in it to share.
        var diagnosticLogURL: URL?
        @Shared(.autoPlayEnabled) public var autoPlayEnabled
        @Shared(.autoPlayPlaylist) public var autoPlayPlaylist
        @Shared(.skipSponsorSegments) public var skipSponsorSegments
        @Presents var videoDetail: VideoDetailReducer.State?
        @Presents var alert: AlertState<AlertAction>?
        #if !os(tvOS)
        /// Whether a YouTube Data API key is saved, for the Discover row.
        var hasYouTubeKey = false
        @Presents var youTubeSetup: DiscoverSetupReducer.State?
        #endif

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
        #if !os(tvOS)
        case confirmRemoveYouTubeKey
        #endif
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
        #if !os(tvOS)
        case youTubeSetup(PresentationAction<DiscoverSetupReducer.Action>)
        case youTubeKeyLoaded(Bool)
        #endif

        @CasePathable
        public enum View {
            case viewDidAppear
            case autoPlayToggled(Bool)
            case autoPlayPlaylistToggled(Bool)
            case skipSponsorSegmentsToggled(Bool)
            case clearDiagnosticLogsTapped
            case logoutTapped
            case rescanSubscriptionsTapped
            case pullToRefreshTriggered
            case downloadsTapped
            case statsTapped
            case historyTapped
            #if !os(tvOS)
            case thirdPartyLibrariesTapped
            case youTubeKeyTapped
            case removeYouTubeKeyTapped
            #endif
        }
    }

    @Dependency(\.diagnosticsLog) var diagnosticsLog
    @Dependency(\.taskService) var taskService
    #if !os(tvOS)
    @Dependency(\.youTubeAPIKeyStore) var youTubeAPIKeyStore
    #endif

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
            #if !os(tvOS)
            case .youTubeKeyLoaded(let hasKey):
                state.hasYouTubeKey = hasKey
                return .none
            case .youTubeSetup(.presented(.delegate(.keySaved))):
                state.hasYouTubeKey = true
                state.youTubeSetup = nil
                return .none
            case .youTubeSetup(.presented(.delegate(.cancelled))):
                state.youTubeSetup = nil
                return .none
            case .alert(.presented(.confirmRemoveYouTubeKey)):
                return handleRemoveYouTubeKeyConfirmed(state: &state)
            case .youTubeSetup:
                return .none
            #endif
            case .alert, .activeTask, .didRequestLogout, .path, .videoDetail:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        #if !os(tvOS)
        .ifLet(\.$youTubeSetup, action: \.youTubeSetup) {
            DiscoverSetupReducer()
        }
        #endif
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
        .forEach(\.path, action: \.path)
    }
}
