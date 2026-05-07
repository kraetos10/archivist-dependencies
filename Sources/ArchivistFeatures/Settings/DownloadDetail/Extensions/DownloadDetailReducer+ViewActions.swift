import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadDetailReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return .none
        case .dismissTapped:
            return .none
        case .downloadTapped:
            return handleDownloadTapped(state: &state)
        case .deleteTapped:
            return handleDeleteTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleDownloadTapped(state: inout State) -> Effect<Action> {
        guard !state.isDownloading, !state.downloadTriggered else { return .none }
        if state.childModeEnabled, !state.childModePin.isEmpty {
            state.isPresentingDownloadPin = true
            return .none
        }
        return performDownload(state: &state)
    }

    func performDownload(state: inout State) -> Effect<Action> {
        guard !state.isDownloading, !state.downloadTriggered else { return .none }
        state.isDownloading = true
        let config = state.serverConfig
        let videoId = state.download.youtubeId
        let downloadService = self.downloadService
        return .run { send in
            let result = await Result {
                try await downloadService.updateDownload(
                    config: config,
                    id: videoId,
                    status: "priority"
                )
            }
            await send(.downloadResult(result))
        }
    }

    private func handleDeleteTapped(state: inout State) -> Effect<Action> {
        guard !state.isDeleting else { return .none }
        state.isDeleting = true
        return .send(.performDelete)
    }
}
