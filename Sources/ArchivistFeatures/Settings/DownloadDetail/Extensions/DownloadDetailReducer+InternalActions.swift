import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadDetailReducer {
    func handlePinLoaded(
        _ pin: String?,
        state: inout State
    ) -> Effect<Action> {
        guard let pin else {
            // Child mode without a stored PIN has nothing to check.
            return performDownload(state: &state)
        }
        state.pinEntry = PinEntryReducer.State(expectedPin: pin)
        return .none
    }

    func performDownload(state: inout State) -> Effect<Action> {
        guard !state.isDownloadBusy else { return .none }
        state.isDownloading = true
        let config = state.serverConfig
        let videoId = state.download.youtubeId
        return .run { [downloadService] send in
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

    func handleDownloadResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isDownloading = false
        switch result {
        case .success:
            // The button stays on its spinner while the screen closes.
            state.downloadTriggered = true
            return finish(with: .didQueueDownload(state.download.youtubeId))
        case .failure(let error):
            state.alert = .requestFailed(error)
            return .none
        }
    }

    func handleDeleteResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isDeleting = false
        switch result {
        case .success:
            return finish(with: .didDelete(state.download.youtubeId))
        case .failure(let error):
            state.alert = .requestFailed(error)
            return .none
        }
    }

    /// Tells the presenter what happened, then closes the screen.
    private func finish(with delegate: Action.Delegate) -> Effect<Action> {
        .run { [dismiss] send in
            await send(.delegate(delegate))
            await dismiss()
        }
    }
}

extension AlertState where Action == DownloadDetailReducer.AlertAction {
    static func requestFailed(_ error: any Error) -> Self {
        AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(error.localizedDescription)
        }
    }
}
