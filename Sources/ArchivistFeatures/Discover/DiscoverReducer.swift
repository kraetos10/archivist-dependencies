#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

/// Search and browse YouTube with the user's own Data API key, then hand
/// what they find to their TubeArchivist server: add a video to the queue,
/// or subscribe to a channel or playlist.
///
/// With nothing searched for, the screen shows shelves built from what the
/// user has watched, then trending, which a category chip narrows.
///
/// The key is read from the Keychain each time the screen appears, so
/// removing it in Settings sends the user back through setup.
@Reducer
public struct DiscoverReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        public enum SearchScope: String, CaseIterable, Sendable, Identifiable {
            case videos
            case channels
            case playlists

            public var id: String { rawValue }
        }

        /// What the server already knows about a video. A video already in
        /// the download queue isn't detected up front — only ones added from
        /// here, so a re-add of a queued video is harmless but not flagged.
        public enum ItemStatus: Equatable, Sendable {
            case inArchive
            case queued
        }

        public var serverConfig: ServerConfig
        public var apiKey: String?
        var hasLoadedKey = false
        var hasLoadedFeed = false
        var hasPromptedSetup = false

        // Search
        var query = ""
        var searchScope: SearchScope = .videos
        var order: YouTubeSearchOrder = .relevance
        var filters = YouTubeSearchFilters()
        /// Narrows Trending; `nil` is the overall chart.
        var trendingCategory: DiscoverCategory?
        /// What the results on screen are for. Typing doesn't change it —
        /// only submitting does, so a search costs quota once, not per key.
        var submittedQuery = ""
        var videos: [YouTubeVideo] = []
        var channels: [YouTubeChannel] = []
        var playlists: [YouTubePlaylist] = []
        var nextPageToken: String?
        var isLoading = false
        var isLoadingMore = false
        var isFiltersPresented = false

        // Shelves above Trending, from what the archive says was watched
        var shelves: [DiscoverShelf] = []
        var isLoadingShelves = false
        /// Rows being switched to another watched video.
        var loadingShelfIds: Set<String> = []

        // Channel page
        var browsedChannel: YouTubeChannel?
        var channelVideos: [YouTubeVideo] = []
        var channelNextPageToken: String?
        var isLoadingChannelVideos = false
        var isLoadingMoreChannelVideos = false

        // Feedback
        var isQuotaExceeded = false
        var errorMessage: String?
        var itemStatus: [String: ItemStatus] = [:]
        var subscribedChannelIds: Set<String> = []
        var subscribedPlaylistIds: Set<String> = []
        /// Video, channel and playlist IDs with a server write in flight.
        var pendingIds: Set<String> = []

        @Presents var setup: DiscoverSetupReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        public init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
        }

        var needsSetup: Bool {
            hasLoadedKey && apiKey == nil
        }

        var isShowingTrending: Bool {
            searchScope == .videos && submittedQuery.isEmpty
        }

        /// Channels and playlists have nothing to show until searched for.
        var showsSearchPrompt: Bool {
            searchScope != .videos && submittedQuery.isEmpty
        }

        /// Sorting and filtering only mean something for a search.
        var showsFilters: Bool {
            !submittedQuery.isEmpty
        }

        var hasActiveFilters: Bool {
            order != .relevance || (searchScope == .videos && filters.isActive)
        }

        /// What is narrowing the search, in words, for the line under the
        /// scope picker. `nil` when nothing is.
        var filterSummary: String? {
            guard showsFilters else { return nil }
            var parts: [String] = []
            if order != .relevance {
                parts.append(String.localised("discover.filters.sortedBy \(order.title)", table: .discover))
            }
            if searchScope == .videos {
                if filters.duration != .any { parts.append(filters.duration.title) }
                if filters.uploaded != .any {
                    parts.append(String.localised("discover.filters.uploaded \(filters.uploaded.title)", table: .discover))
                }
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }

        /// The shelves stay put when a category is chosen: only Trending
        /// beneath them changes.
        var showsShelves: Bool {
            isShowingTrending && !shelves.isEmpty
        }

        /// Placeholder rows while the shelves are being built.
        var showsShelfSkeleton: Bool {
            isShowingTrending && shelves.isEmpty && (isLoadingShelves || !hasLoadedKey)
        }

        var showsTrendingSkeleton: Bool {
            isLoading || (!hasLoadedFeed && errorMessage == nil && !isQuotaExceeded)
        }

        /// A chosen category keeps its row even when empty or failed, so the
        /// chips are still there to pick another.
        var showsTrendingRow: Bool {
            trendingCategory != nil || showsTrendingSkeleton || !videos.isEmpty || showsNoResults
        }

        /// The watched videos a row can be switched to: not the ones other
        /// rows are already based on.
        func choices(for shelf: DiscoverShelf) -> [DiscoverShelf.Choice] {
            let usedElsewhere = Set(shelves.filter { $0.id != shelf.id }.compactMap(\.seedId))
            return shelf.choices.filter { !usedElsewhere.contains($0.videoId) }
        }

        var emptyScopeIsEmpty: Bool {
            switch searchScope {
            case .videos: videos.isEmpty
            case .channels: channels.isEmpty
            case .playlists: playlists.isEmpty
            }
        }

        var showsNoResults: Bool {
            hasLoadedFeed
                && !isLoading
                && errorMessage == nil
                && !isQuotaExceeded
                && !showsSearchPrompt
                && emptyScopeIsEmpty
        }

        var canLoadMore: Bool {
            nextPageToken != nil && !isLoading && !isLoadingMore
        }

        var canLoadMoreChannelVideos: Bool {
            channelNextPageToken != nil && !isLoadingChannelVideos && !isLoadingMoreChannelVideos
        }

        func status(of video: YouTubeVideo) -> ItemStatus? {
            itemStatus[video.videoId]
        }

        func isPending(_ id: String) -> Bool {
            pendingIds.contains(id)
        }

        func isSubscribed(_ channel: YouTubeChannel) -> Bool {
            subscribedChannelIds.contains(channel.channelId)
        }
    }

    public enum AlertAction: Equatable, Sendable {}

    public enum DiscoverFeedPage: Equatable, Sendable {
        case videos(YouTubePage<YouTubeVideo>)
        case channels(YouTubePage<YouTubeChannel>)
        case playlists(YouTubePage<YouTubePlaylist>)
    }

    public enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case setup(PresentationAction<DiscoverSetupReducer.Action>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case keyLoaded(String?)
        case feedResult(append: Bool, Result<DiscoverFeedPage, Error>)
        case channelFeedResult(append: Bool, Result<YouTubePage<YouTubeVideo>, Error>)
        case channelDetailsLoaded(Result<YouTubeChannel, Error>)
        case shelvesLoaded(Result<[DiscoverShelf], Error>)
        case becauseShelfLoaded(shelfId: String, Result<DiscoverShelf?, Error>)
        case statusesLoaded(
            archived: Set<String>,
            subscribed: Set<String>,
            subscribedPlaylists: Set<String>
        )
        case addResult(videoId: String, Result<Void, Error>)
        case subscribeResult(channelId: String, Result<Void, Error>)
        case subscribePlaylistResult(playlistId: String, Result<Void, Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case searchSubmitted
            case retryTapped
            case lastItemAppeared
            case channelLastItemAppeared
            case addToQueueTapped(YouTubeVideo, startNow: Bool)
            case subscribeTapped(YouTubeChannel)
            case subscribePlaylistTapped(YouTubePlaylist)
            case categorySelected(DiscoverCategory?)
            case filtersTapped
            case resetFiltersTapped
            case becauseVideoSelected(shelfId: String, DiscoverShelf.Choice)
            case channelTapped(YouTubeChannel)
            case videoChannelTapped(YouTubeVideo)
            case setUpKeyTapped
        }

        @CasePathable
        public enum Delegate: Equatable {
            /// A video was added on the server, so the active task may have
            /// changed.
            case didQueueDownload
        }
    }

    enum CancelID: Hashable {
        case feed
        case channelFeed
        case shelves
        case because(String)
    }

    @Dependency(\.youTubeSearchService) var youTubeSearchService
    @Dependency(\.youTubeAPIKeyStore) var youTubeAPIKeyStore
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.channelService) var channelService
    @Dependency(\.videoService) var videoService
    @Dependency(\.playlistService) var playlistService
    @Dependency(\.discoverCache) var discoverCache
    @Dependency(\.date.now) var now

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(let bindingAction):
                return handleBinding(bindingAction, state: &state)
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .setup(.presented(.delegate(.keySaved(let key)))):
                return handleKeySaved(key, state: &state)
            case .setup(.presented(.delegate(.cancelled))):
                state.setup = nil
                return .none
            case .setup, .alert, .delegate:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$setup, action: \.setup) {
            DiscoverSetupReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
#endif
