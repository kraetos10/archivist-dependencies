import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddChannelReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            return handleAddButtonTapped(state: &state)
        case .pinConfirmed:
            state.pinRequest = nil
            return performSubscribe(state: &state)
        case .pinCancelled:
            state.pinRequest = nil
            return .none
        }
    }

    private func handleAddButtonTapped(state: inout State) -> Effect<Action> {
        guard state.canSubmit else { return .none }
        if state.childModeEnabled, let pin = pinStore.load() {
            state.pinRequest = ChildModePinRequest(
                expectedPin: pin,
                purpose: .subscribe
            )
            return .none
        }
        return performSubscribe(state: &state)
    }

    private func performSubscribe(state: inout State) -> Effect<Action> {
        guard state.canSubmit else { return .none }
        state.isSubscribing = true
        let config = state.serverConfig
        let item = ChannelSubscribeItem(channelId: state.trimmedInput, channelSubscribed: true)
        let channelService = self.channelService
        return .run { send in
            let result = await Result {
                try await channelService.subscribeChannels(config: config, items: [item])
            }
            await send(.subscribeResult(result))
        }
    }
}
