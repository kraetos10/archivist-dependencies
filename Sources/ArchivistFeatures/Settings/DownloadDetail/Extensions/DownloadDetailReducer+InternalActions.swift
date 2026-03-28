import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadDetailReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .downloadResult(.success):
            state.isDownloading = false
            state.downloadTriggered = true
            return .none
        case .downloadResult(.failure):
            state.isDownloading = false
            return .none
        case .performDelete:
            let config = state.serverConfig
            let videoId = state.download.youtubeId
            let downloadService = self.downloadService
            return .run { send in
                let result = await Result {
                    try await downloadService.deleteDownload(config: config, id: videoId)
                }
                await send(.deleteResult(result))
            }
        case .deleteResult(.success):
            state.isDeleting = false
            return .none
        case .deleteResult(.failure):
            state.isDeleting = false
            return .none
        default:
            return .none
        }
    }
}
