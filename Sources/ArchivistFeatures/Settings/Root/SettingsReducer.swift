import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum SettingsDetail: String, Hashable, Sendable {
    case queue
    case stats
    #if !os(tvOS)
    case deviceDownloads
    #endif
    case history
}

@Reducer
public struct SettingsReducer {
    public init() {}
    @ObservableState
    public struct State: Sendable {
        var serverConfig: ServerConfig
        var downloads: DownloadsReducer.State
        var stats: StatsReducer.State
        var activeTask: ActiveTaskReducer.State
        #if !os(tvOS)
        var deviceDownloads: DeviceDownloadsReducer.State
        #endif
        var history: HistoryReducer.State
        var selectedDetail: SettingsDetail?
        var isRescanningSubscriptions = false
        var isReAuthenticating = false
        @Shared(.appStorage("autoPlayEnabled")) public var autoPlayEnabled = true
        @Presents var videoDetail: VideoDetailReducer.State?

        public init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
            self.downloads = DownloadsReducer.State(serverConfig: serverConfig)
            self.stats = StatsReducer.State(serverConfig: serverConfig)
            self.activeTask = ActiveTaskReducer.State(serverConfig: serverConfig)
            #if !os(tvOS)
            self.deviceDownloads = DeviceDownloadsReducer.State(serverConfig: serverConfig)
            #endif
            self.history = HistoryReducer.State(serverConfig: serverConfig)
        }
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case didRequestLogout
        case rescanSubscriptionsResult(Result<Void, Error>)
        case reAuthResult(Result<String, Error>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case downloads(DownloadsReducer.Action)
        case stats(StatsReducer.Action)
        case activeTask(ActiveTaskReducer.Action)
        #if !os(tvOS)
        case deviceDownloads(DeviceDownloadsReducer.Action)
        #endif
        case history(HistoryReducer.Action)

        @CasePathable
        public enum View {
            case logoutTapped
            case rescanSubscriptionsTapped
            case pullToRefreshTriggered
            case reAuthTapped
        }
    }

    @Dependency(\.taskService) var taskService
    @Dependency(\.keychainService) var keychainService
    @Dependency(\.userService) var userService

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.downloads, action: \.downloads) {
            DownloadsReducer()
        }
        Scope(state: \.stats, action: \.stats) {
            StatsReducer()
        }
        Scope(state: \.activeTask, action: \.activeTask) {
            ActiveTaskReducer()
        }
        #if !os(tvOS)
        Scope(state: \.deviceDownloads, action: \.deviceDownloads) {
            DeviceDownloadsReducer()
        }
        #endif
        Scope(state: \.history, action: \.history) {
            HistoryReducer()
        }
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
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
    }
}
