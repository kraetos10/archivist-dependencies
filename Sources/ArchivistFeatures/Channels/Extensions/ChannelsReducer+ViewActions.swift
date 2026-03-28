import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelsReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
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
        case .newFilterToggled(let showNewOnly):
            state.showNewOnly = showNewOnly
            return .none
        case .splitViewEnabled:
            state.useSplitView = true
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        // Refresh new content badges every time view appears
        let refreshBadges: Effect<Action> = .run { [newContentSyncManager] send in
            let ids = await newContentSyncManager.allNewChannelIds()
            await send(.newContentIdsLoaded(ids))
        }

        guard state.channels.isEmpty, !state.isLoading else {
            return refreshBadges
        }

        state.isLoading = true
        let config = state.serverConfig
        let channelService = self.channelService
        return .merge(
            refreshBadges,
            .run { send in
                let result = await Result {
                    try await channelService.getChannels(
                        config: config,
                        page: 1,
                        filter: nil,
                        query: nil
                    )
                }
                await send(.channelsResult(result))
            }
            .cancellable(id: CancelID.loadChannels)
        )
    }

    private func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.currentPage = 1
        let config = state.serverConfig
        let channelService = self.channelService
        return .run { send in
            let result = await Result {
                try await channelService.getChannels(
                    config: config,
                    page: 1,
                    filter: nil,
                    query: nil
                )
            }
            await send(.channelsResult(result))
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
            let result = await Result {
                try await channelService.getChannels(
                    config: config,
                    page: nextPage,
                    filter: nil,
                    query: nil
                )
            }
            await send(.channelsResult(result))
        }
        .cancellable(id: CancelID.loadChannels)
    }

    private func handleChannelTapped(
        _ channel: ChannelResponse,
        state: inout State
    ) -> Effect<Action> {
        if state.useSplitView {
            guard state.selectedChannel?.channel.channelId != channel.channelId else {
                return .none
            }
        }
        // Clear the "new" badge when the user taps a channel
        state.channelIdsWithNewContent.remove(channel.channelId)
        var detailState = ChannelDetailReducer.State(
            serverConfig: state.serverConfig,
            channel: channel
        )
        detailState.newContentSince = UserDefaults.standard.object(
            forKey: "newContentSync.lastLaunchDate"
        ) as? Date
        state.selectedChannel = detailState
        if !state.useSplitView {
            state.path.append(.channelDetail(detailState))
        }
        let channelId = channel.channelId
        return .run { [newContentSyncManager] _ in
            await newContentSyncManager.markSeen(channelId: channelId)
        }
    }

    private func handleAddChannelTapped(state: inout State) -> Effect<Action> {
        state.addChannel = AddChannelReducer.State(serverConfig: state.serverConfig)
        return .none
    }

    private func handleUnsubscribeTapped(
        _ channel: ChannelResponse,
        state: inout State
    ) -> Effect<Action> {
        state.alert = AlertState {
            TextState(String.localised("generic.unsubscribe", table: .generic))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: .confirmUnsubscribe(channel.channelId)) {
                TextState(String.localised("generic.unsubscribe", table: .generic))
            }
        } message: {
            TextState(
                String.localised(
                    "Are you sure you want to unsubscribe from \(channel.channelName)?",
                    table: .login
                )
            )
        }
        return .none
    }

    public func handleConfirmedUnsubscribe(
        _ channelId: String,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let channelService = self.channelService
        return .run { send in
            let result = await Result {
                try await channelService.deleteChannel(config: config, id: channelId)
            }
            await send(.unsubscribeResult(result.map { channelId }))
        }
    }
}
