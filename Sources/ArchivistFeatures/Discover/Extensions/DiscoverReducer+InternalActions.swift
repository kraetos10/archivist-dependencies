#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DiscoverReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .keyLoaded(let key):
            return handleKeyLoaded(key, state: &state)
        case .feedResult(let append, let result):
            return handleFeedResult(result, append: append, state: &state)
        case .channelFeedResult(let append, let result):
            return handleChannelFeedResult(result, append: append, state: &state)
        case .channelDetailsLoaded(let result):
            return handleChannelDetailsLoaded(result, state: &state)
        case .shelvesLoaded(let result):
            return handleShelvesLoaded(result, state: &state)
        case .becauseShelfLoaded(let shelfId, let result):
            return handleBecauseShelfLoaded(shelfId: shelfId, result: result, state: &state)
        case .statusesLoaded(let archived, let subscribed, let subscribedPlaylists):
            return handleStatusesLoaded(
                archived: archived,
                subscribed: subscribed,
                subscribedPlaylists: subscribedPlaylists,
                state: &state
            )
        case .addResult(let videoId, let result):
            return handleAddResult(videoId: videoId, result: result, state: &state)
        case .subscribeResult(let channelId, let result):
            return handleSubscribeResult(channelId: channelId, result: result, state: &state)
        case .subscribePlaylistResult(let playlistId, let result):
            return handleSubscribePlaylistResult(playlistId: playlistId, result: result, state: &state)
        default:
            return .none
        }
    }

    // MARK: - Binding

    func handleBinding(
        _ action: BindingAction<State>,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case \.searchScope, \.order, \.filters, \.filters.duration, \.filters.uploaded:
            // A new scope, sort or filter is a new search, but only worth
            // running when there's something to run it for.
            guard state.apiKey != nil else { return .none }
            if state.searchScope != .videos && state.submittedQuery.isEmpty {
                state.videos = []
                state.channels = []
                state.playlists = []
                state.nextPageToken = nil
                state.errorMessage = nil
                state.isLoading = false
                return .cancel(id: CancelID.feed)
            }
            return reloadFeed(state: &state)
        case \.query:
            // Clearing the field (its X button) goes back to Trending.
            guard state.query.isEmpty, !state.submittedQuery.isEmpty else { return .none }
            state.submittedQuery = ""
            return reloadFeed(state: &state)
        case \.browsedChannel:
            // The channel page was popped.
            guard state.browsedChannel == nil else { return .none }
            state.channelVideos = []
            state.channelNextPageToken = nil
            state.isLoadingChannelVideos = false
            state.isLoadingMoreChannelVideos = false
            return .cancel(id: CancelID.channelFeed)
        default:
            return .none
        }
    }

    // MARK: - Key

    func handleKeyLoaded(
        _ key: String?,
        state: inout State
    ) -> Effect<Action> {
        state.hasLoadedKey = true
        guard let key else {
            state.apiKey = nil
            state.videos = []
            state.channels = []
            state.nextPageToken = nil
            state.hasLoadedFeed = false
            state.isLoading = false
            state.shelves = []
            state.isLoadingShelves = false
            state.loadingShelfIds = []
            if !state.hasPromptedSetup {
                state.hasPromptedSetup = true
                state.setup = DiscoverSetupReducer.State()
            }
            return .merge(.cancel(id: CancelID.feed), .cancel(id: CancelID.shelves))
        }
        if state.apiKey == key, state.hasLoadedFeed || state.isLoading {
            return .none
        }
        state.apiKey = key
        return .merge(reloadFeed(state: &state), loadShelves(state: &state))
    }

    func handleKeySaved(
        _ key: String,
        state: inout State
    ) -> Effect<Action> {
        state.setup = nil
        state.apiKey = key
        state.hasLoadedKey = true
        state.isQuotaExceeded = false
        return .merge(reloadFeed(state: &state), loadShelves(state: &state))
    }

    // MARK: - Feed

    /// Starts again from page one for the current query, scope and sort.
    func reloadFeed(state: inout State) -> Effect<Action> {
        state.videos = []
        state.channels = []
        state.playlists = []
        state.nextPageToken = nil
        state.isLoadingMore = false
        return loadFeed(append: false, state: &state)
    }

    func loadFeed(
        append: Bool,
        state: inout State
    ) -> Effect<Action> {
        guard let key = state.apiKey else { return .none }
        let query = state.submittedQuery
        let searchScope = state.searchScope
        let order = state.order
        let filters = state.filters
        let category = state.trendingCategory?.rawValue
        let pageToken: String?
        if append {
            guard state.canLoadMore, let token = state.nextPageToken else { return .none }
            state.isLoadingMore = true
            pageToken = token
        } else {
            // Channels and playlists have no Trending to fall back on.
            guard searchScope == .videos || !query.isEmpty else {
                state.isLoading = false
                return .cancel(id: CancelID.feed)
            }
            state.isLoading = true
            state.errorMessage = nil
            pageToken = nil
        }
        let region = Locale.current.region?.identifier
        return .run { [youTubeSearchService] send in
            let result = await Result { () -> DiscoverFeedPage in
                switch searchScope {
                case .videos where query.isEmpty:
                    return .videos(
                        try await youTubeSearchService.trending(
                            key: key,
                            regionCode: region,
                            categoryId: category,
                            pageToken: pageToken
                        )
                    )
                case .videos:
                    return .videos(
                        try await youTubeSearchService.searchVideos(
                            key: key,
                            query: query,
                            order: order,
                            filters: filters,
                            pageToken: pageToken
                        )
                    )
                case .playlists:
                    return .playlists(
                        try await youTubeSearchService.searchPlaylists(
                            key: key,
                            query: query,
                            pageToken: pageToken
                        )
                    )
                case .channels:
                    return .channels(
                        try await youTubeSearchService.searchChannels(
                            key: key,
                            query: query,
                            pageToken: pageToken
                        )
                    )
                }
            }
            await send(.feedResult(append: append, result))
        }
        .cancellable(id: CancelID.feed, cancelInFlight: true)
    }

    func handleFeedResult(
        _ result: Result<DiscoverFeedPage, Error>,
        append: Bool,
        state: inout State
    ) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        switch result {
        case .success(let page):
            state.hasLoadedFeed = true
            state.isQuotaExceeded = false
            state.errorMessage = nil
            switch page {
            case .videos(let page):
                // A page-one response replaces the list; later pages append.
                let known = Set(state.videos.map(\.videoId))
                state.videos = append
                    ? state.videos + page.items.filter { !known.contains($0.videoId) }
                    : page.items
                state.nextPageToken = page.nextPageToken
                return statusEffect(
                    videoIds: page.items.map(\.videoId),
                    channelIds: [],
                    state: state
                )
            case .channels(let page):
                let known = Set(state.channels.map(\.channelId))
                state.channels = append
                    ? state.channels + page.items.filter { !known.contains($0.channelId) }
                    : page.items
                state.nextPageToken = page.nextPageToken
                return statusEffect(
                    videoIds: [],
                    channelIds: page.items.map(\.channelId),
                    state: state
                )
            case .playlists(let page):
                let known = Set(state.playlists.map(\.playlistId))
                state.playlists = append
                    ? state.playlists + page.items.filter { !known.contains($0.playlistId) }
                    : page.items
                state.nextPageToken = page.nextPageToken
                return statusEffect(
                    videoIds: [],
                    channelIds: [],
                    playlistIds: page.items.map(\.playlistId),
                    state: state
                )
            }
        case .failure(let error):
            return handleFailure(error, state: &state)
        }
    }

    // MARK: - Channel page

    func loadChannelFeed(
        append: Bool,
        state: inout State
    ) -> Effect<Action> {
        guard let key = state.apiKey, let channel = state.browsedChannel else { return .none }
        let pageToken: String?
        if append {
            guard state.canLoadMoreChannelVideos, let token = state.channelNextPageToken else { return .none }
            state.isLoadingMoreChannelVideos = true
            pageToken = token
        } else {
            state.isLoadingChannelVideos = true
            state.errorMessage = nil
            pageToken = nil
        }
        let channelId = channel.channelId
        return .run { [youTubeSearchService] send in
            let result = await Result {
                try await youTubeSearchService.channelUploads(
                    key: key,
                    channelId: channelId,
                    pageToken: pageToken
                )
            }
            await send(.channelFeedResult(append: append, result))
        }
        .cancellable(id: CancelID.channelFeed, cancelInFlight: true)
    }

    func handleChannelFeedResult(
        _ result: Result<YouTubePage<YouTubeVideo>, Error>,
        append: Bool,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingChannelVideos = false
        state.isLoadingMoreChannelVideos = false
        switch result {
        case .success(let page):
            state.errorMessage = nil
            let known = Set(state.channelVideos.map(\.videoId))
            state.channelVideos = append
                ? state.channelVideos + page.items.filter { !known.contains($0.videoId) }
                : page.items
            state.channelNextPageToken = page.nextPageToken
            return statusEffect(
                videoIds: page.items.map(\.videoId),
                channelIds: [],
                state: state
            )
        case .failure(let error):
            return handleFailure(error, state: &state)
        }
    }

    func handleChannelDetailsLoaded(
        _ result: Result<YouTubeChannel, Error>,
        state: inout State
    ) -> Effect<Action> {
        // The header is a nicety: if the lookup fails the channel page still
        // works from the little the tap carried.
        guard case .success(let channel) = result,
              state.browsedChannel?.channelId == channel.channelId else { return .none }
        state.browsedChannel = channel
        return .none
    }

    // MARK: - Failures

    func handleFailure(
        _ error: Error,
        state: inout State
    ) -> Effect<Action> {
        if error is CancellationError { return .none }
        switch error as? YouTubeError {
        case .quotaExceeded:
            state.isQuotaExceeded = true
        case .invalidKey:
            // The saved key is dead. Forget it and send the user back
            // through setup, on the paste step, with a note saying why.
            try? youTubeAPIKeyStore.clear()
            state.apiKey = nil
            state.hasLoadedFeed = false
            state.videos = []
            state.channels = []
            state.browsedChannel = nil
            state.setup = DiscoverSetupReducer.State(wasKeyRejected: true)
        case .apiNotEnabled:
            state.errorMessage = String.localised("discover.setup.failure.apiNotEnabled", table: .discover)
        case .network:
            state.errorMessage = String.localised("discover.error.network", table: .discover)
        default:
            state.errorMessage = String.localised("discover.error.unexpected", table: .discover)
        }
        return .none
    }

    // MARK: - Archive status

    /// Asks the server which of these it already has. A lookup that fails
    /// (not found, offline) just leaves the item looking addable.
    func statusEffect(
        videoIds: [String],
        channelIds: [String],
        playlistIds: [String] = [],
        state: State
    ) -> Effect<Action> {
        let videoIds = videoIds.filter { state.itemStatus[$0] == nil }
        let channelIds = channelIds.filter { !state.subscribedChannelIds.contains($0) }
        let playlistIds = playlistIds.filter { !state.subscribedPlaylistIds.contains($0) }
        guard !videoIds.isEmpty || !channelIds.isEmpty || !playlistIds.isEmpty else { return .none }
        let config = state.serverConfig
        return .run { [videoService, channelService, playlistService] send in
            enum Kind { case video, channel, playlist }
            var archived = Set<String>()
            var subscribed = Set<String>()
            var subscribedPlaylists = Set<String>()
            await withTaskGroup(of: (id: String, kind: Kind, found: Bool).self) { group in
                for id in videoIds {
                    group.addTask {
                        let video = try? await videoService.getVideo(config: config, id: id)
                        return (id, .video, video != nil)
                    }
                }
                for id in channelIds {
                    group.addTask {
                        let channel = try? await channelService.getChannel(config: config, id: id)
                        return (id, .channel, channel?.channelSubscribed == true)
                    }
                }
                for id in playlistIds {
                    group.addTask {
                        let playlist = try? await playlistService.getPlaylist(config: config, id: id)
                        return (id, .playlist, playlist?.playlistSubscribed == true)
                    }
                }
                for await outcome in group where outcome.found {
                    switch outcome.kind {
                    case .video: archived.insert(outcome.id)
                    case .channel: subscribed.insert(outcome.id)
                    case .playlist: subscribedPlaylists.insert(outcome.id)
                    }
                }
            }
            await send(
                .statusesLoaded(
                    archived: archived,
                    subscribed: subscribed,
                    subscribedPlaylists: subscribedPlaylists
                )
            )
        }
    }

    func handleStatusesLoaded(
        archived: Set<String>,
        subscribed: Set<String>,
        subscribedPlaylists: Set<String>,
        state: inout State
    ) -> Effect<Action> {
        for id in archived {
            state.itemStatus[id] = .inArchive
        }
        state.subscribedChannelIds.formUnion(subscribed)
        state.subscribedPlaylistIds.formUnion(subscribedPlaylists)
        return .none
    }

    // MARK: - Server writes

    func handleAddResult(
        videoId: String,
        result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.pendingIds.remove(videoId)
        switch result {
        case .success:
            state.itemStatus[videoId] = .queued
            return .send(.delegate(.didQueueDownload))
        case .failure:
            state.alert = AlertState {
                TextState(String.localised("discover.error.title", table: .discover))
            } message: {
                TextState(String.localised("discover.error.addFailed", table: .discover))
            }
            return .none
        }
    }

    func handleSubscribePlaylistResult(
        playlistId: String,
        result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.pendingIds.remove(playlistId)
        switch result {
        case .success:
            state.subscribedPlaylistIds.insert(playlistId)
            return .none
        case .failure:
            state.alert = AlertState {
                TextState(String.localised("discover.error.title", table: .discover))
            } message: {
                TextState(String.localised("discover.error.subscribeFailed", table: .discover))
            }
            return .none
        }
    }

    func handleSubscribeResult(
        channelId: String,
        result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.pendingIds.remove(channelId)
        switch result {
        case .success:
            state.subscribedChannelIds.insert(channelId)
            return .none
        case .failure:
            state.alert = AlertState {
                TextState(String.localised("discover.error.title", table: .discover))
            } message: {
                TextState(String.localised("discover.error.subscribeFailed", table: .discover))
            }
            return .none
        }
    }
}
#endif
