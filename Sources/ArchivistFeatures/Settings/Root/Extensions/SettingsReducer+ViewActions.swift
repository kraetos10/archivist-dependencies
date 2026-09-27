import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension SettingsReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return .run { [diagnosticsLog] send in
                await send(.diagnosticLogLoaded(diagnosticsLog.logFileURL()))
            }
        case .autoPlayToggled(let isOn):
            state.$autoPlayEnabled.withLock { $0 = isOn }
            return .none
        case .autoPlayPlaylistToggled(let isOn):
            state.$autoPlayPlaylist.withLock { $0 = isOn }
            return .none
        case .clearDiagnosticLogsTapped:
            state.diagnosticLogURL = nil
            return .run { [diagnosticsLog] _ in
                await diagnosticsLog.clear()
            }
        case .logoutTapped:
            return .send(.didRequestLogout)
        case .rescanSubscriptionsTapped:
            return handleRescanSubscriptionsTapped(state: &state)
        case .pullToRefreshTriggered:
            return .send(.activeTask(.startPolling))
        case .downloadsTapped:
            state.path.append(
                .downloads(DownloadsReducer.State(serverConfig: state.serverConfig))
            )
            return .none
        case .statsTapped:
            state.path.append(
                .stats(StatsReducer.State(serverConfig: state.serverConfig))
            )
            return .none
        case .historyTapped:
            state.path.append(
                .history(HistoryReducer.State(serverConfig: state.serverConfig))
            )
            return .none
        #if !os(tvOS)
        case .thirdPartyLibrariesTapped:
            state.path.append(.thirdPartyLibraries(ThirdPartyLibrariesReducer.State()))
            return .none
        #endif
        }
    }

    // MARK: - Private Handlers

    private func handleRescanSubscriptionsTapped(state: inout State) -> Effect<Action> {
        guard !state.isRescanningSubscriptions else { return .none }
        state.isRescanningSubscriptions = true
        let config = state.serverConfig
        return .run { [taskService] send in
            let result = await Result {
                _ = try await taskService.startTask(config: config, name: TaskName.updateSubscribed.rawValue)
            }
            await send(.rescanSubscriptionsResult(result))
        }
    }
}
