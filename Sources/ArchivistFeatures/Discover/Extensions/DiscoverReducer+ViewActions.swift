#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DiscoverReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear()
        case .searchSubmitted:
            return handleSearchSubmitted(state: &state)
        case .retryTapped:
            return handleRetryTapped(state: &state)
        case .lastItemAppeared:
            return loadFeed(append: true, state: &state)
        case .channelLastItemAppeared:
            return loadChannelFeed(append: true, state: &state)
        case .addToQueueTapped(let video, let startNow):
            return handleAddToQueueTapped(video, startNow: startNow, state: &state)
        case .subscribeTapped(let channel):
            return handleSubscribeTapped(channel, state: &state)
        case .subscribePlaylistTapped(let playlist):
            return handleSubscribePlaylistTapped(playlist, state: &state)
        case .categorySelected(let category):
            return handleCategorySelected(category, state: &state)
        case .filtersTapped:
            state.isFiltersPresented = true
            return .none
        case .resetFiltersTapped:
            state.order = .relevance
            state.filters = YouTubeSearchFilters()
            guard state.apiKey != nil, !state.submittedQuery.isEmpty else { return .none }
            return reloadFeed(state: &state)
        case .becauseVideoSelected(let shelfId, let choice):
            return handleBecauseVideoSelected(shelfId: shelfId, choice: choice, state: &state)
        case .channelTapped(let channel):
            return openChannel(channel, state: &state)
        case .videoChannelTapped(let video):
            return openChannel(
                YouTubeChannel(channelId: video.channelId, title: video.channelTitle),
                state: &state
            )
        case .setUpKeyTapped:
            state.setup = DiscoverSetupReducer.State()
            return .none
        }
    }

    func handleViewDidAppear() -> Effect<Action> {
        // Re-read every time: the key may have been removed in Settings.
        .run { [youTubeAPIKeyStore] send in
            await send(.keyLoaded(youTubeAPIKeyStore.load()))
        }
    }

    func handleSearchSubmitted(state: inout State) -> Effect<Action> {
        let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        state.submittedQuery = trimmed
        return reloadFeed(state: &state)
    }

    func handleRetryTapped(state: inout State) -> Effect<Action> {
        if state.browsedChannel != nil {
            return loadChannelFeed(append: false, state: &state)
        }
        return reloadFeed(state: &state)
    }

    func handleAddToQueueTapped(
        _ video: YouTubeVideo,
        startNow: Bool,
        state: inout State
    ) -> Effect<Action> {
        guard state.itemStatus[video.videoId] == nil,
              !state.pendingIds.contains(video.videoId) else { return .none }
        state.pendingIds.insert(video.videoId)
        let config = state.serverConfig
        let videoId = video.videoId
        return .run { [downloadService] send in
            let result = await Result {
                try await downloadService.addDownloads(
                    config: config,
                    items: [AddDownloadItem(youtubeId: videoId, status: "pending")],
                    autostart: startNow,
                    flat: true,
                    force: false
                )
            }
            await send(.addResult(videoId: videoId, result))
        }
    }

    func handleSubscribeTapped(
        _ channel: YouTubeChannel,
        state: inout State
    ) -> Effect<Action> {
        guard !state.subscribedChannelIds.contains(channel.channelId),
              !state.pendingIds.contains(channel.channelId) else { return .none }
        state.pendingIds.insert(channel.channelId)
        let config = state.serverConfig
        let channelId = channel.channelId
        return .run { [channelService] send in
            let result = await Result {
                try await channelService.subscribeChannels(
                    config: config,
                    items: [ChannelSubscribeItem(channelId: channelId, channelSubscribed: true)]
                )
            }
            await send(.subscribeResult(channelId: channelId, result))
        }
    }

    func handleSubscribePlaylistTapped(
        _ playlist: YouTubePlaylist,
        state: inout State
    ) -> Effect<Action> {
        guard !state.subscribedPlaylistIds.contains(playlist.playlistId),
              !state.pendingIds.contains(playlist.playlistId) else { return .none }
        state.pendingIds.insert(playlist.playlistId)
        let config = state.serverConfig
        let playlistId = playlist.playlistId
        return .run { [playlistService] send in
            let result = await Result {
                try await playlistService.subscribePlaylists(
                    config: config,
                    items: [PlaylistSubscribeItem(playlistId: playlistId, playlistSubscribed: true)]
                )
            }
            await send(.subscribePlaylistResult(playlistId: playlistId, result))
        }
    }

    func handleCategorySelected(
        _ category: DiscoverCategory?,
        state: inout State
    ) -> Effect<Action> {
        guard state.trendingCategory != category else { return .none }
        state.trendingCategory = category
        return reloadFeed(state: &state)
    }

    func openChannel(
        _ channel: YouTubeChannel,
        state: inout State
    ) -> Effect<Action> {
        state.browsedChannel = channel
        state.channelVideos = []
        state.channelNextPageToken = nil
        guard let key = state.apiKey else { return .none }
        let channelId = channel.channelId
        let details: Effect<Action> = .run { [youTubeSearchService] send in
            let result = await Result {
                try await youTubeSearchService.channelDetails(key: key, channelId: channelId)
            }
            await send(.channelDetailsLoaded(result))
        }
        return .merge(
            loadChannelFeed(append: false, state: &state),
            details,
            statusEffect(videoIds: [], channelIds: [channelId], state: state)
        )
    }
}
#endif
