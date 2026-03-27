import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ActiveTaskReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .notificationsLoaded(let notifications):
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
        case .pollFailed:
            state.activeDownload = nil
            state.activeTaskId = nil
            state.isPolling = false
            state.isCancelling = false
            return .none
        case .taskCancelled:
            state.isCancelling = false
            return .none
        case .taskCancelFailed:
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
            do {
                let notifications = try await taskService.getDownloadNotifications(config: config)
                await send(.notificationsLoaded(notifications))
            } catch {
                await send(.pollFailed)
            }
        }
        .cancellable(id: CancelID.polling, cancelInFlight: true)
    }
}
