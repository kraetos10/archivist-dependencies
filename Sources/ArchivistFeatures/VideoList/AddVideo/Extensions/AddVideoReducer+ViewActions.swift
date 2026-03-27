import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddVideoReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            return handleAddButtonTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleAddButtonTapped(state: inout State) -> Effect<Action> {
        let input = state.videoInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .none }
        state.isAdding = true
        let config = state.serverConfig
        let videoIds = input
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let items = videoIds.map { AddDownloadItem(youtubeId: $0, status: "pending") }
        guard !items.isEmpty else {
            state.isAdding = false
            return .none
        }
        let playlistId = state.playlistId
        let downloadService = self.downloadService
        let playlistService = self.playlistService
        return .run { send in
            try await downloadService.addDownloads(config: config, items: items)
            if let playlistId {
                for videoId in videoIds {
                    try? await playlistService.modifyCustomPlaylist(
                        config: config,
                        id: playlistId,
                        action: "create",
                        videoId: videoId
                    )
                }
            }
            await send(.addSucceeded)
        } catch: { _, send in
            await send(.addFailed)
        }
    }
}
