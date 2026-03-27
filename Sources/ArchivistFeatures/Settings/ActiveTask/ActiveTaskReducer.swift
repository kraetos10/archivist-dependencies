import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct ActiveTaskReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var activeDownload: ActiveDownload?
        var isPolling = false
        var isCancelling = false
        var activeTaskId: String?
    }

    public enum Action: ViewAction {
        case view(View)
        case notificationsLoaded([NotificationResponse])
        case pollFailed
        case downloadCompleted
        case taskCancelled
        case taskCancelFailed

        @CasePathable
        public enum View {
            case startPolling
            case cancelTaskTapped
        }
    }

    @Dependency(\.taskService) var taskService
    @Dependency(\.continuousClock) var clock

    nonisolated enum CancelID: Hashable, Sendable {
        case polling
    }

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
