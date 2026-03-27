import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelsReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleOnAppear(state: &state)
        case .pullToRefreshTriggered:
            return handleRefreshTriggered(state: &state)
        case .lastItemAppeared:
            return handleLoadNextPage(state: &state)
        case .channelTapped(let channel):
            return handleChannelTapped(channel, state: &state)
        case .addChannelTapped:
            return handleAddChannelTapped(state: &state)
        case .unsubscribeTapped(let channel):
            return handleUnsubscribeTapped(channel, state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        guard state.channels.isEmpty, !state.isLoading else { return .none }
        state.isLoading = true
        let config = state.serverConfig
        let channelService = self.channelService
        return .run { send in
            do {
                let response = try await channelService.getChannels(
                    config: config,
                    page: 1,
                    filter: nil,
                    query: nil
                )
                await send(.channelsLoaded(response))
            } catch {
                await send(.channelsFailed(error))
            }
        }
        .cancellable(id: CancelID.loadChannels)
    }

    private func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.currentPage = 1
        let config = state.serverConfig
        let channelService = self.channelService
        return .run { send in
            do {
                let response = try await channelService.getChannels(
                    config: config,
                    page: 1,
                    filter: nil,
                    query: nil
                )
                await send(.channelsLoaded(response))
            } catch {
                await send(.channelsFailed(error))
            }
        }
        .cancellable(id: CancelID.loadChannels, cancelInFlight: true)
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage, !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        let config = state.serverConfig
        let nextPage = state.currentPage + 1
        let channelService = self.channelService
        return .run { send in
            do {
                let response = try await channelService.getChannels(
                    config: config,
                    page: nextPage,
                    filter: nil,
                    query: nil
                )
                await send(.channelsLoaded(response))
            } catch {
                await send(.channelsFailed(error))
            }
        }
        .cancellable(id: CancelID.loadChannels)
    }

    private func handleChannelTapped(_ channel: ChannelResponse, state: inout State) -> Effect<Action> {
        if state.useSplitView {
            guard state.selectedChannel?.channel.channelId != channel.channelId else {
                return .none
            }
        }
        let detailState = ChannelDetailReducer.State(
            serverConfig: state.serverConfig,
            channel: channel
        )
        state.selectedChannel = detailState
        if !state.useSplitView {
            state.path.append(.channelDetail(detailState))
        }
        return .none
    }

    private func handleAddChannelTapped(state: inout State) -> Effect<Action> {
        state.addChannel = AddChannelReducer.State(serverConfig: state.serverConfig)
        return .none
    }

    private func handleUnsubscribeTapped(_ channel: ChannelResponse, state: inout State) -> Effect<Action> {
        state.alert = AlertState {
            TextState(String.localised("generic.unsubscribe"))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel"))
            }
            ButtonState(role: .destructive, action: .confirmUnsubscribe(channel.channelId)) {
                TextState(String.localised("generic.unsubscribe"))
            }
        } message: {
            TextState(String.localised("Are you sure you want to unsubscribe from \(channel.channelName)?", table: .login))
        }
        return .none
    }

    public func handleConfirmedUnsubscribe(_ channelId: String, state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let channelService = self.channelService
        return .run { send in
            do {
                try await channelService.deleteChannel(config: config, id: channelId)
                await send(.unsubscribeCompleted(channelId))
            } catch {
                await send(.unsubscribeFailed)
            }
        }
    }
}
