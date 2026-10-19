#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

/// Search and browse YouTube with the user's own Data API key, then hand
/// what they find to their TubeArchivist server: add a video to the queue,
/// or subscribe to a channel.
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
        /// What the results on screen are for. Typing doesn't change it —
        /// only submitting does, so a search costs quota once, not per key.
        var submittedQuery = ""
        var videos: [YouTubeVideo] = []
        var channels: [YouTubeChannel] = []
        var nextPageToken: String?
        var isLoading = false
        var isLoadingMore = false

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
        /// Video and channel IDs with a server write in flight.
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

        var showsChannelPrompt: Bool {
            searchScope == .channels && submittedQuery.isEmpty
        }

        var showsNoResults: Bool {
            hasLoadedFeed
                && !isLoading
                && errorMessage == nil
                && !isQuotaExceeded
                && !showsChannelPrompt
                && (searchScope == .videos ? videos.isEmpty : channels.isEmpty)
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
        case statusesLoaded(archived: Set<String>, subscribed: Set<String>)
        case addResult(videoId: String, Result<Void, Error>)
        case subscribeResult(channelId: String, Result<Void, Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case searchSubmitted
            case retryTapped
            case lastItemAppeared
            case channelLastItemAppeared
            case addToQueueTapped(YouTubeVideo, startNow: Bool)
            case subscribeTapped(YouTubeChannel)
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

    enum CancelID {
        case feed
        case channelFeed
    }

    @Dependency(\.youTubeSearchService) var youTubeSearchService
    @Dependency(\.youTubeAPIKeyStore) var youTubeAPIKeyStore
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.channelService) var channelService
    @Dependency(\.videoService) var videoService

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
