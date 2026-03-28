import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddPlaylistReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            return handleAddButtonTapped(state: &state)
        case .createCustomTapped:
            return handleCreateCustomTapped(state: &state)
        }
    }

    private func handleAddButtonTapped(state: inout State) -> Effect<Action> {
        let input = state.playlistInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .none }
        state.isSubscribing = true
        let config = state.serverConfig
        let item = PlaylistSubscribeItem(playlistId: input, playlistSubscribed: true)
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.subscribePlaylists(config: config, items: [item])
            }
            await send(.subscribeResult(result))
        }
    }

    private func handleCreateCustomTapped(state: inout State) -> Effect<Action> {
        let name = state.customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .none }
        state.isSubscribing = true
        let config = state.serverConfig
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.createCustomPlaylist(config: config, name: name)
            }
            await send(.createCustomResult(result))
        }
    }
}
