import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddPlaylistReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            guard state.canSubscribe else { return .none }
            return requirePin(for: .subscribe, state: &state)
        case .createCustomTapped:
            guard state.canCreateCustom else { return .none }
            return requirePin(for: .createCustom, state: &state)
        case .pinConfirmed:
            let purpose = state.pinRequest?.purpose
            state.pinRequest = nil
            return purpose.map { perform($0, state: &state) } ?? .none
        case .pinCancelled:
            state.pinRequest = nil
            return .none
        }
    }

    /// In child mode both subscribing and creating need the PIN first.
    private func requirePin(
        for purpose: ChildModePinRequest.Purpose,
        state: inout State
    ) -> Effect<Action> {
        if state.childModeEnabled, let pin = pinStore.load() {
            state.pinRequest = ChildModePinRequest(
                expectedPin: pin,
                purpose: purpose
            )
            return .none
        }
        return perform(purpose, state: &state)
    }

    private func perform(
        _ purpose: ChildModePinRequest.Purpose,
        state: inout State
    ) -> Effect<Action> {
        switch purpose {
        case .subscribe:
            return performSubscribe(state: &state)
        case .createCustom:
            return performCreateCustom(state: &state)
        }
    }

    private func performSubscribe(state: inout State) -> Effect<Action> {
        guard state.canSubscribe else { return .none }
        state.isSubscribing = true
        let config = state.serverConfig
        let item = PlaylistSubscribeItem(
            playlistId: state.trimmedPlaylistInput,
            playlistSubscribed: true
        )
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.subscribePlaylists(config: config, items: [item])
            }
            await send(.subscribeResult(result))
        }
    }

    private func performCreateCustom(state: inout State) -> Effect<Action> {
        guard state.canCreateCustom else { return .none }
        state.isSubscribing = true
        let config = state.serverConfig
        let name = state.trimmedCustomName
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                try await playlistService.createCustomPlaylist(config: config, name: name)
            }
            await send(.createCustomResult(result))
        }
    }
}
