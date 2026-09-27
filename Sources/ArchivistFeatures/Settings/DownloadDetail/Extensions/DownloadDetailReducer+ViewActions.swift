import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadDetailReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .downloadTapped:
            return handleDownloadTapped(state: &state)
        case .deleteTapped:
            return handleDeleteTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    /// In child mode, downloading asks for the PIN first. It's read from
    /// the Keychain, so the check happens off the reducer.
    private func handleDownloadTapped(state: inout State) -> Effect<Action> {
        guard !state.isDownloadBusy else { return .none }
        guard state.childModeEnabled else {
            return performDownload(state: &state)
        }
        return .run { [pinStore] send in
            await send(.pinLoaded(pinStore.load()))
        }
    }

    private func handleDeleteTapped(state: inout State) -> Effect<Action> {
        guard !state.isDeleting else { return .none }
        state.isDeleting = true
        let config = state.serverConfig
        let videoId = state.download.youtubeId
        return .run { [downloadService] send in
            let result = await Result {
                try await downloadService.deleteDownload(config: config, id: videoId)
            }
            await send(.deleteResult(result))
        }
    }
}
