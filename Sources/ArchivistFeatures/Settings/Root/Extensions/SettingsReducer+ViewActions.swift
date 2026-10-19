import ArchivistComponents
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
            return handleViewDidAppear()
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
        case .youTubeKeyTapped:
            state.youTubeSetup = DiscoverSetupReducer.State()
            return .none
        case .removeYouTubeKeyTapped:
            state.alert = AlertState {
                TextState(String.localised("settings.youtubeKey.removeTitle", table: .settings))
            } actions: {
                ButtonState(role: .destructive, action: .confirmRemoveYouTubeKey) {
                    TextState(String.localised("settings.youtubeKey.remove", table: .settings))
                }
                ButtonState(role: .cancel) {
                    TextState(String.localised("generic.cancel", table: .generic))
                }
            } message: {
                TextState(String.localised("settings.youtubeKey.removeMessage", table: .settings))
            }
            return .none
        #endif
        }
    }

    func handleViewDidAppear() -> Effect<Action> {
        #if os(tvOS)
        return .run { [diagnosticsLog] send in
            await send(.diagnosticLogLoaded(diagnosticsLog.logFileURL()))
        }
        #else
        return .merge(
            .run { [diagnosticsLog] send in
                await send(.diagnosticLogLoaded(diagnosticsLog.logFileURL()))
            },
            .run { [youTubeAPIKeyStore] send in
                await send(.youTubeKeyLoaded(youTubeAPIKeyStore.load() != nil))
            }
        )
        #endif
    }

    #if !os(tvOS)
    func handleRemoveYouTubeKeyConfirmed(state: inout State) -> Effect<Action> {
        try? youTubeAPIKeyStore.clear()
        state.hasYouTubeKey = false
        return .none
    }
    #endif

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
