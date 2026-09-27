import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum ChannelListFilter: String, Sendable, Equatable {
    case all
    case withUnwatched
}

/// What the channel list shows. Worked out once per read so the view only
/// switches on it, and so the filtered list is built a single time.
public enum ChannelsContent: Equatable, Sendable {
    case placeholders
    case emptyUnwatched
    case noChannels
    case noSearchResults
    case channels(IdentifiedArrayOf<ChannelResponse>)
}

@Reducer
public struct ChannelsReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var channels: IdentifiedArrayOf<ChannelResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var hasLoaded = false
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<ChannelResponse> = []
        var isSearching = false
        var useSplitView = false
        var channelIdsWithUnwatchedVideos: Set<String> = []
        var isLoadingUnwatchedIds = false
        @Shared(.channelsFilter) var filter
        @Shared(.autoPlayEnabled) var autoPlayEnabled

        @Presents var alert: AlertState<AlertAction>?
        @Presents var addChannel: AddChannelReducer.State?
        @Presents var videoDetail: VideoDetailReducer.State?
        /// The detail shown beside the list in split view (iPad), or
        /// presented over the tvOS home screen. Never set alongside a `path`
        /// push — a channel detail has exactly one home.
        @Presents var selectedChannel: ChannelDetailReducer.State?
        // Stack navigation (iPhone, tvOS "All channels")
        var path = StackState<ChannelsPath.State>()

        var isSearchActive: Bool {
            !searchQuery.isEmpty
        }

        var filteredChannels: IdentifiedArrayOf<ChannelResponse> {
            let base: IdentifiedArrayOf<ChannelResponse>
            if isSearchActive {
                let localMatches = channels.filter {
                    $0.channelName.localizedStandardContains(searchQuery)
                }
                var merged = searchResults
                for channel in localMatches {
                    merged.updateOrAppend(channel)
                }
                base = merged
            } else {
                base = channels
            }
            switch filter {
            case .all:
                return base
            case .withUnwatched:
                return base.filter { channelIdsWithUnwatchedVideos.contains($0.channelId) }
            }
        }

        var content: ChannelsContent {
            let filtered = filteredChannels
            guard filtered.isEmpty else { return .channels(filtered) }
            if hasLoaded {
                if filter == .withUnwatched { return .emptyUnwatched }
                return searchQuery.isEmpty ? .noChannels : .noSearchResults
            }
            return isLoading ? .placeholders : .channels([])
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case confirmUnsubscribe(String)
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case alert(PresentationAction<AlertAction>)
        case channelsResult(Result<PaginatedResponse<ChannelResponse>, Error>)
        case channelDetail(PresentationAction<ChannelDetailReducer.Action>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case path(StackActionOf<ChannelsPath>)

        case addChannel(PresentationAction<AddChannelReducer.Action>)
        case refreshPendingDownloads
        /// Open a channel's detail from outside the tab — the channel name
        /// on a video detail screen.
        case openChannel(ChannelResponse)

        case searchResult(Result<[ChannelResponse], Error>)
        case unsubscribeResult(Result<String, Error>)
        case unwatchedChannelIdsLoaded(Set<String>)

        @CasePathable
        public enum View {
            case viewDidAppear
            /// The iPad split view appeared: switch to split-view selection
            /// and load, in one step.
            case splitViewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case channelTapped(ChannelResponse)
            case addChannelTapped
            case unsubscribeTapped(ChannelResponse)
            case filterChanged(ChannelListFilter)
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        case loadChannels
        case search
        case unwatchedIds
    }

    @Dependency(\.channelService) var channelService
    @Dependency(\.searchService) var searchService
    @Dependency(\.videoService) var videoService
    @Dependency(\.continuousClock) var clock

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchQuery):
                return handleSearchQueryChanged(state: &state)
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .channelDetail(.presented(.delegate(.didUnsubscribe(let channelId)))):
                return handleSelectedChannelUnsubscribed(channelId, state: &state)
            case .path(.element(id: let id, action: .channelDetail(.delegate(.didUnsubscribe(let channelId))))):
                return handlePushedChannelUnsubscribed(
                    channelId,
                    elementID: id,
                    state: &state
                )
            case .channelDetail(.presented(.delegate(.videoSelected(let video, let nextVideos)))),
                 .path(.element(_, action: .channelDetail(.delegate(.videoSelected(let video, let nextVideos))))):
                return handleVideoSelected(
                    video,
                    nextVideos: nextVideos,
                    state: &state
                )
            case .refreshPendingDownloads:
                return handleRefreshPendingDownloads(state: &state)
            case .addChannel(.presented(.delegate(.didSubscribe))):
                return handleSubscribeSucceeded(state: &state)
            case .alert(.presented(.confirmUnsubscribe(let channelId))):
                return handleConfirmedUnsubscribe(channelId, state: &state)
            case .alert:
                return .none
            case .videoDetail(.presented(.delegate(.didRequestMinimize))),
                 .videoDetail(.presented(.delegate(.didDismiss))):
                state.videoDetail = nil
                return .none
            case .videoDetail, .addChannel, .channelDetail, .path:
                return .none
            case .channelsResult, .searchResult, .unsubscribeResult,
                 .unwatchedChannelIdsLoaded, .openChannel:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$addChannel, action: \.addChannel) {
            AddChannelReducer()
        }
        .ifLet(\.$selectedChannel, action: \.channelDetail) {
            ChannelDetailReducer()
        }
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
        .forEach(\.path, action: \.path)
    }
}
