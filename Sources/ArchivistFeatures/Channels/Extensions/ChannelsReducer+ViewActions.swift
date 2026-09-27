import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelsReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleOnAppear(state: &state)
        case .splitViewDidAppear:
            return handleSplitViewDidAppear(state: &state)
        case .pullToRefreshTriggered:
            return refreshChannels(state: &state)
        case .lastItemAppeared:
            return loadNextPage(state: &state)
        case .channelTapped(let channel):
            return handleChannelTapped(channel, state: &state)
        case .addChannelTapped:
            return handleAddChannelTapped(state: &state)
        case .unsubscribeTapped(let channel):
            return handleUnsubscribeTapped(channel, state: &state)
        case .filterChanged(let filter):
            state.$filter.withLock { $0 = filter }
            return .none
        }
    }

    // MARK: - Shared

    /// Reloads the first page and the unwatched-channel set. Cancels any
    /// in-flight page so a late page can't land on top of the fresh list.
    func refreshChannels(state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.currentPage = 1
        state.isLoadingUnwatchedIds = true
        return .merge(
            fetchUnwatchedChannelIdsEffect(config: state.serverConfig),
            fetchChannels(page: 1, state: state)
                .cancellable(id: CancelID.loadChannels, cancelInFlight: true)
        )
    }

    func loadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage,
              !state.isLoadingMore,
              !state.isLoading else { return .none }
        state.isLoadingMore = true
        return fetchChannels(page: state.currentPage + 1, state: state)
            .cancellable(id: CancelID.loadChannels)
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        state.isLoadingUnwatchedIds = true
        let refreshUnwatched = fetchUnwatchedChannelIdsEffect(config: state.serverConfig)

        guard state.channels.isEmpty, !state.isLoading else {
            return refreshUnwatched
        }

        state.isLoading = true
        return .merge(
            refreshUnwatched,
            fetchChannels(page: 1, state: state)
                .cancellable(id: CancelID.loadChannels)
        )
    }

    /// The split view never shows `path`. A channel opened before it first
    /// appeared (from a video, say) was pushed; move it into the selection.
    private func handleSplitViewDidAppear(state: inout State) -> Effect<Action> {
        state.useSplitView = true
        if state.selectedChannel == nil,
           case .channelDetail(let detail)? = state.path.last {
            state.selectedChannel = detail
        }
        state.path.removeAll()
        return handleOnAppear(state: &state)
    }

    private func fetchChannels(
        page: Int,
        state: State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let channelService = self.channelService
        return .run { send in
            let result = await Result {
                try await channelService.getChannels(
                    config: config,
                    page: page,
                    filter: nil,
                    query: nil
                )
            }
            await send(.channelsResult(result))
        }
    }

    /// Paginate the global unwatched video list and collect the distinct
    /// channel ids. Capped at a sensible page budget to avoid pathological
    /// fetches on libraries with huge unwatched backlogs — this is a
    /// best-effort filter, not an authoritative set. A new request replaces
    /// one still paging, so repeat appearances don't stack.
    private func fetchUnwatchedChannelIdsEffect(
        config: ServerConfig
    ) -> Effect<Action> {
        let videoService = self.videoService
        return .run { send in
            var ids: Set<String> = []
            let maxPages = 10
            var page = 1
            while page <= maxPages {
                do {
                    let response = try await videoService.getVideos(
                        config: config,
                        page: page,
                        sort: nil,
                        order: nil,
                        type: nil,
                        watch: "unwatched",
                        channel: nil,
                        playlist: nil
                    )
                    for video in response.data {
                        ids.insert(video.channelId)
                    }
                    if page >= response.paginate.lastPage { break }
                    page += 1
                } catch is CancellationError {
                    return
                } catch {
                    break
                }
            }
            await send(.unwatchedChannelIdsLoaded(ids))
        }
        .cancellable(id: CancelID.unwatchedIds, cancelInFlight: true)
    }

    private func handleChannelTapped(
        _ channel: ChannelResponse,
        state: inout State
    ) -> Effect<Action> {
        let detailState = ChannelDetailReducer.State(
            serverConfig: state.serverConfig,
            channel: channel
        )
        if state.useSplitView {
            guard state.selectedChannel?.channel.channelId != channel.channelId else {
                return .none
            }
            state.selectedChannel = detailState
        } else {
            state.path.append(.channelDetail(detailState))
        }
        return .none
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
                    "channel.unsubscribeConfirm \(channel.channelName)",
                    table: .login
                )
            )
        }
        return .none
    }

    func handleConfirmedUnsubscribe(
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
