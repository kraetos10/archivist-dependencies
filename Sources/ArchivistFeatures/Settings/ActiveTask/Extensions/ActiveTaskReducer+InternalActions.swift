import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ActiveTaskReducer {
    func handleStartPolling(state: inout State) -> Effect<Action> {
        guard !state.isPolling else { return .none }
        return poll(config: state.serverConfig, after: nil)
    }

    func handlePollResult(
        _ result: Result<[NotificationResponse], Error>,
        state: inout State
    ) -> Effect<Action> {
        switch result {
        case .success(let notifications):
            if let notification = notifications.first {
                state.activeDownload = ActiveDownload(
                    title: notification.title ?? "",
                    messages: notification.messages ?? [],
                    progress: notification.progress.map { $0 / 100.0 }
                )
                state.activeTaskId = notification.id
                state.isPolling = true
                return poll(config: state.serverConfig, after: .seconds(3))
            }
            let hadActive = state.activeDownload != nil
            clearActiveTask(state: &state)
            return hadActive ? .send(.downloadCompleted) : .none
        case .failure:
            // Polling is best-effort: the next `startPolling` retries.
            clearActiveTask(state: &state)
            return .none
        }
    }

    func handleCancelTaskResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isCancelling = false
        if case .failure(let error) = result {
            state.alert = AlertState {
                TextState(String.localised("settings.cancelTaskFailed", table: .settings))
            } message: {
                TextState(error.localizedDescription)
            }
        }
        return .none
    }

    // MARK: - Private Helpers

    private func clearActiveTask(state: inout State) {
        state.activeDownload = nil
        state.activeTaskId = nil
        state.isPolling = false
        state.isCancelling = false
    }

    private func poll(
        config: ServerConfig,
        after delay: Duration?
    ) -> Effect<Action> {
        .run { [clock, taskService] send in
            if let delay {
                try await clock.sleep(for: delay)
            }
            let result = await Result {
                try await taskService.getDownloadNotifications(config: config)
            }
            await send(.pollResult(result))
        }
        .cancellable(id: CancelID.polling, cancelInFlight: true)
    }
}
