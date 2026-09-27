import ArchivistComponents
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
        @Presents var alert: AlertState<AlertAction>?

        /// What the server says it's doing, or a generic "Downloading".
        var stepDescription: String {
            guard let step = activeDownload?.currentStep, !step.isEmpty else {
                return String.localised("video.downloading", table: .videos)
            }
            return step
        }

        /// Earlier steps, listed with a tick above the current one.
        var completedMessages: [String] {
            guard let messages = activeDownload?.messages, messages.count > 1 else { return [] }
            return Array(messages.dropLast())
        }

        init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case pollResult(Result<[NotificationResponse], Error>)
        /// Entry point for parents: check the server for a running task.
        case startPolling
        case downloadCompleted
        case cancelTaskResult(Result<Void, Error>)

        @CasePathable
        public enum View {
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
            case .startPolling:
                return handleStartPolling(state: &state)
            case .pollResult(let result):
                return handlePollResult(result, state: &state)
            case .cancelTaskResult(let result):
                return handleCancelTaskResult(result, state: &state)
            case .alert, .downloadCompleted:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

}
