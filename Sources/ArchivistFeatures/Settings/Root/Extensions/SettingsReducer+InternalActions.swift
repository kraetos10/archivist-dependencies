import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension SettingsReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .activeTask(.downloadCompleted):
            return .send(.downloads(.view(.pullToRefreshTriggered)))
        case .rescanSubscriptionsResult(.success):
            state.isRescanningSubscriptions = false
            return .send(.activeTask(.view(.startPolling)))
        case .rescanSubscriptionsResult(.failure):
            state.isRescanningSubscriptions = false
            return .none
        case .history(.delegate(.videoSelected(let video))):
            state.videoDetail = VideoDetailReducer.State(
                serverConfig: state.serverConfig,
                video: video,
                nextVideos: []
            )
            return .none
        #if !os(tvOS)
        case .deviceDownloads(.delegate(.playVideo(let video))):
            state.videoDetail = VideoDetailReducer.State(
                serverConfig: state.serverConfig,
                video: video,
                nextVideos: []
            )
            return .none
        case .deviceDownloads:
            return .none
        #endif
        case .videoDetail:
            return .none
        case .reAuthResult(.success(let token)):
            state.isReAuthenticating = false
            state.serverConfig = ServerConfig(
                baseURL: state.serverConfig.baseURL,
                port: state.serverConfig.port,
                apiToken: token,
                useHTTP: state.serverConfig.useHTTP
            )
            return .none
        case .reAuthResult(.failure):
            state.isReAuthenticating = false
            return .none
        case .didRequestLogout, .downloads, .stats, .activeTask, .history:
            return .none
        default:
            return .none
        }
    }
}
