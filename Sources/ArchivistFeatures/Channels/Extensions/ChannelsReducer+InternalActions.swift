import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelsReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .channelsResult(.success(let response)):
            return handleChannelsLoaded(response, state: &state)
        case .channelsResult(.failure):
            return handleChannelsFailed(state: &state)
        case .searchResult(.success(let channels)):
            state.searchResults = IdentifiedArrayOf(uniqueElements: channels)
            state.isSearching = false
            return .none
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .unsubscribeResult(.success(let channelId)):
            state.channels.remove(id: channelId)
            return .none
        case .unsubscribeResult(.failure):
            state.alert = .unsubscribeFailed
            return .none
        case .openChannel(let channel):
            return handleOpenChannel(channel, state: &state)
        case .unwatchedChannelIdsLoaded(let ids):
            state.channelIdsWithUnwatchedVideos = ids
            state.isLoadingUnwatchedIds = false
            return .none
        default:
            return .none
        }
    }

    // MARK: - Child delegates

    func handleSelectedChannelUnsubscribed(
        _ channelId: String,
        state: inout State
    ) -> Effect<Action> {
        state.channels.remove(id: channelId)
        state.selectedChannel = nil
        return .none
    }

    func handlePushedChannelUnsubscribed(
        _ channelId: String,
        elementID: StackElementID,
        state: inout State
    ) -> Effect<Action> {
        state.channels.remove(id: channelId)
        state.path.pop(from: elementID)
        return .none
    }

    func handleVideoSelected(
        _ video: VideoResponse,
        nextVideos: [VideoResponse],
        state: inout State
    ) -> Effect<Action> {
        state.videoDetail = VideoDetailReducer.State(
            serverConfig: state.serverConfig,
            video: video,
            nextVideos: nextVideos,
            shouldAutoPlayNextVideo: state.autoPlayEnabled
        )
        return .none
    }

    /// A server download finished: every open channel detail — the split
    /// view selection and anything pushed on the stack — reloads its
    /// pending downloads. This is the parent telling its children, not the
    /// reducer re-entering itself.
    func handleRefreshPendingDownloads(state: inout State) -> Effect<Action> {
        var effects: [Effect<Action>] = []
        if state.selectedChannel != nil {
            effects.append(.send(.channelDetail(.presented(.refreshPendingDownloads))))
        }
        for id in state.path.ids {
            effects.append(.send(.path(.element(id: id, action: .channelDetail(.refreshPendingDownloads)))))
        }
        return .merge(effects)
    }

    func handleSubscribeSucceeded(state: inout State) -> Effect<Action> {
        // AddChannel dismisses itself; the list just picks up the new channel.
        refreshChannels(state: &state)
    }

    // MARK: - Private Handlers

    private func handleChannelsLoaded(
        _ response: PaginatedResponse<ChannelResponse>,
        state: inout State
    ) -> Effect<Action> {
        let isFirstPage = response.paginate.currentPage <= 1
        let visibleCountBefore = isFirstPage ? 0 : state.filteredChannels.count
        if isFirstPage {
            state.channels = IdentifiedArrayOf(uniqueElements: response.data)
        } else {
            for channel in response.data {
                state.channels.updateOrAppend(channel)
            }
        }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true

        // Paging is driven by the last *rendered* card appearing. Under a
        // filter, a page can add nothing visible, so that card never
        // re-appears and paging would stall — fetch on until something
        // shows up or the pages run out.
        if state.filter != .all,
           state.filteredChannels.count == visibleCountBefore,
           state.currentPage < state.lastPage {
            return loadNextPage(state: &state)
        }
        return .none
    }

    private func handleChannelsFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }

    func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.searchResults = []
            state.isSearching = false
            return .cancel(id: CancelID.search)
        }
        state.isSearching = true
        let config = state.serverConfig
        let clock = self.clock
        let searchService = self.searchService
        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            let result = await Result {
                try await searchService.search(config: config, query: query)
            }
            await send(.searchResult(result.map { $0.channelResults ?? [] }))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    /// Shows the channel on its own over the list, replacing whatever was
    /// pushed, so Back returns to the channel list rather than to a screen
    /// the user left before opening the video. If the iPad split view
    /// hasn't appeared yet the push is moved into the selection when it
    /// does (`handleSplitViewDidAppear`).
    private func handleOpenChannel(
        _ channel: ChannelResponse,
        state: inout State
    ) -> Effect<Action> {
        let detailState = ChannelDetailReducer.State(
            serverConfig: state.serverConfig,
            channel: channel
        )
        state.path.removeAll()
        if state.useSplitView {
            state.selectedChannel = detailState
        } else {
            state.selectedChannel = nil
            state.path.append(.channelDetail(detailState))
        }
        return .none
    }
}

extension AlertState where Action == ChannelsReducer.AlertAction {
    static var unsubscribeFailed: Self {
        AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(String.localised("channel.unsubscribeFailed", table: .login))
        }
    }
}
