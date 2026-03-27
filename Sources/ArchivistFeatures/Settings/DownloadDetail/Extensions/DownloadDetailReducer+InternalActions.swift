import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadDetailReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .downloadStarted:
            state.isDownloading = false
            state.downloadTriggered = true
            return .none
        case .downloadFailed:
            state.isDownloading = false
            return .none
        case .performDelete:
            let config = state.serverConfig
            let videoId = state.download.youtubeId
            let downloadService = self.downloadService
            return .run { send in
                do {
                    try await downloadService.deleteDownload(config: config, id: videoId)
                    await send(.deleteSucceeded)
                } catch {
                    await send(.deleteFailed(error))
                }
            }
        case .deleteSucceeded:
            state.isDeleting = false
            return .none
        case .deleteFailed:
            state.isDeleting = false
            return .none
        default:
            return .none
        }
    }
}
