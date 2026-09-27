import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ActiveTaskReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .cancelTaskTapped:
            guard let taskId = state.activeTaskId, !state.isCancelling else { return .none }
            state.isCancelling = true
            let config = state.serverConfig
            return .run { [taskService] send in
                let result = await Result {
                    try await taskService.sendTaskCommand(config: config, taskId: taskId, command: "stop")
                }
                await send(.cancelTaskResult(result))
            }
        }
    }
}
