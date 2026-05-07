import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct SettingsReducer {
    public init() {}
    @ObservableState
    public struct State: Sendable {
        public var serverConfig: ServerConfig
        var activeTask: ActiveTaskReducer.State
        var path = StackState<SettingsPath.State>()
        var isRescanningSubscriptions = false
        var isReAuthenticating = false
        var supportURL: URL?
        @Shared(.appStorage("autoPlayEnabled")) public var autoPlayEnabled = true
        @Shared(.appStorage("autoPlayPlaylist")) public var autoPlayPlaylist = true
        @Shared(.appStorage(ChildMode.enabledKey)) public var childModeEnabled = false
        @Presents var videoDetail: VideoDetailReducer.State?
        @Presents var alert: AlertState<AlertAction>?

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

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case didRequestLogout
        case didRefreshToken(String)
        case rescanSubscriptionsResult(Result<Void, Error>)
        case reAuthResult(Result<String, Error>)
        case alert(PresentationAction<AlertAction>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case activeTask(ActiveTaskReducer.Action)
        case path(StackActionOf<SettingsPath>)

        @CasePathable
        public enum View {
            case logoutTapped
            case rescanSubscriptionsTapped
            case pullToRefreshTriggered
            case reAuthTapped
            case downloadsTapped
            case statsTapped
            #if !os(tvOS)
            case deviceDownloadsTapped
            #endif
            case historyTapped
            #if !os(watchOS)
            case playbackCacheTapped
            #endif
            #if !os(tvOS)
            case thirdPartyLibrariesTapped
            #endif
        }
    }

    @Dependency(\.taskService) var taskService
    @Dependency(\.keychainService) var keychainService
    @Dependency(\.userService) var userService

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.activeTask, action: \.activeTask) {
            ActiveTaskReducer()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .alert:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .videoDetail(.presented(.delegate(.didRequestMinimize))):
                state.videoDetail = nil
                return .none
            case .videoDetail(.presented(.delegate(.didDismiss))):
                state.videoDetail = nil
                return .none
            case .path(.element(_, action: .history(.delegate(.videoSelected(let video))))):
                @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled1 = true
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: [],
                    shouldAutoPlayNextVideo: autoPlayEnabled1
                )
                return .none
            #if !os(tvOS)
            case .path(.element(_, action: .deviceDownloads(.delegate(.playVideo(let video, let nextVideos))))):
                @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled2 = true
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: nextVideos,
                    shouldAutoPlayNextVideo: autoPlayEnabled2
                )
                return .none
            #endif
            case .path:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
        .forEach(\.path, action: \.path)
    }
}
