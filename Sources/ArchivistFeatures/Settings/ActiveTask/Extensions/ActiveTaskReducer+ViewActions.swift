import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ActiveTaskReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .startPolling:
            guard !state.isPolling else { return .none }
            return poll(config: state.serverConfig)
        case .cancelTaskTapped:
            guard let taskId = state.activeTaskId, !state.isCancelling else { return .none }
            state.isCancelling = true
            let config = state.serverConfig
            let taskService = self.taskService
            return .run { send in
                try await taskService.sendTaskCommand(config: config, taskId: taskId, command: "stop")
                await send(.taskCancelled)
            } catch: { _, send in
                await send(.taskCancelFailed)
            }
        }
    }

    // MARK: - Private Helpers

    private func poll(config: ServerConfig) -> Effect<Action> {
        let taskService = self.taskService
        return .run { send in
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
