import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddVideoReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            return handleAddButtonTapped(state: &state)
        case .pinConfirmed:
            state.isPresentingPin = false
            state.expectedPin = ""
            return performAdd(state: &state)
        case .pinCancelled:
            state.isPresentingPin = false
            state.expectedPin = ""
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleAddButtonTapped(state: inout State) -> Effect<Action> {
        guard state.canAdd else { return .none }
        // In child mode adding needs the PIN first. `load()` returns nil
        // when none is set, in which case there's nothing to ask for.
        if state.childModeEnabled, let pin = pinStore.load() {
            state.expectedPin = pin
            state.isPresentingPin = true
            return .none
        }
        return performAdd(state: &state)
    }

    func performAdd(state: inout State) -> Effect<Action> {
        let input = state.trimmedInput
        guard !input.isEmpty else { return .none }
        let videoIds = input
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let items = videoIds.map { AddDownloadItem(youtubeId: $0, status: "pending") }
        guard !items.isEmpty else { return .none }
        state.isAdding = true
        let config = state.serverConfig
        let playlistId = state.playlistId
        let autostart = state.autoDownload
        let flat = state.fastAdd
        let force = state.reDownload
        return .run { [downloadService, playlistService] send in
            let result = await Result {
                try await downloadService.addDownloads(
                    config: config,
                    items: items,
                    autostart: autostart,
                    flat: flat,
                    force: force
                )
                if let playlistId {
                    for videoId in videoIds {
                        try await playlistService.modifyCustomPlaylist(
                            config: config,
                            id: playlistId,
                            action: "create",
                            videoId: videoId
                        )
                    }
                }
            }
            await send(.addResult(result))
        }
    }
}
