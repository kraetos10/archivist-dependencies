import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddChannelReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .addButtonTapped:
            return handleAddButtonTapped(state: &state)
        }
    }

    private func handleAddButtonTapped(state: inout State) -> Effect<Action> {
        let input = state.channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .none }
        state.isSubscribing = true
        let config = state.serverConfig
        let item = ChannelSubscribeItem(channelId: input, channelSubscribed: true)
        let channelService = self.channelService
        return .run { send in
            let result = await Result {
                try await channelService.subscribeChannels(config: config, items: [item])
            }
            await send(.subscribeResult(result))
        }
    }
}
