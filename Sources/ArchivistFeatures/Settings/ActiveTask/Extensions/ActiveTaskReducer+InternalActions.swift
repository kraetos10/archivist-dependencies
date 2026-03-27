import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ActiveTaskReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .pollResult(.success(let notifications)):
            if let notification = notifications.first {
                let title = notification.title ?? ""
                let normalizedProgress = notification.progress.map { $0 / 100.0 }
                state.activeDownload = ActiveDownload(
                    title: title,
                    messages: notification.messages ?? [],
                    progress: normalizedProgress
                )
                state.activeTaskId = notification.id
                state.isPolling = true
                return scheduleNextPoll(config: state.serverConfig)
            } else {
                let hadActive = state.activeDownload != nil
                state.activeDownload = nil
                state.activeTaskId = nil
                state.isPolling = false
                state.isCancelling = false
                if hadActive {
                    return .send(.downloadCompleted)
                }
                return .none
            }
        case .pollResult(.failure):
            state.activeDownload = nil
            state.activeTaskId = nil
            state.isPolling = false
            state.isCancelling = false
            return .none
        case .cancelTaskResult(.success):
            state.isCancelling = false
            return .none
        case .cancelTaskResult(.failure):
            state.isCancelling = false
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Helpers

    private func scheduleNextPoll(config: ServerConfig) -> Effect<Action> {
        let clock = self.clock
        let taskService = self.taskService
        return .run { send in
            try await clock.sleep(for: .seconds(3))
            let result = await Result {
                try await taskService.getDownloadNotifications(config: config)
            }
            await send(.pollResult(result))
        }
        .cancellable(id: CancelID.polling, cancelInFlight: true)
    }
}
