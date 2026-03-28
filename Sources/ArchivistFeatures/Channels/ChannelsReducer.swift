import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct ChannelsReducer {
    public init() {}
    @ObservableState
    public struct State: Sendable {
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

        @Presents var alert: AlertState<AlertAction>?
        @Presents var addChannel: AddChannelReducer.State?
        @Presents var videoDetail: VideoDetailReducer.State?
        // Split view (iPad)
        @Presents var selectedChannel: ChannelDetailReducer.State?
        // Stack navigation (iPhone)
        var path = StackState<ChannelsPath.State>()

        var isSearchActive: Bool {
            !searchQuery.isEmpty
        }

        var filteredChannels: IdentifiedArrayOf<ChannelResponse> {
            guard isSearchActive else { return channels }
            let localMatches = channels.filter {
                $0.channelName.localizedCaseInsensitiveContains(searchQuery)
            }
            var merged = searchResults
            for channel in localMatches {
                merged.updateOrAppend(channel)
            }
            return merged
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

        case searchResult(Result<[ChannelResponse], Error>)
        case unsubscribeResult(Result<String, Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case channelTapped(ChannelResponse)
            case addChannelTapped
            case unsubscribeTapped(ChannelResponse)
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        case loadChannels
        case search
    }

    @Dependency(\.channelService) var channelService
    @Dependency(\.searchService) var searchService
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
            case .channelDetail(.presented(.unsubscribeResult(.success))):
                if let channelId = state.selectedChannel?.channel.channelId {
                    state.channels.remove(id: channelId)
                }
                state.selectedChannel = nil
                return .none
            case .channelDetail(.presented(.delegate(.videoSelected(let video, let nextVideos)))):
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: nextVideos
                )
                return .none
            case .path(.element(_, action: .channelDetail(.delegate(.videoSelected(let video, let nextVideos))))):
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: nextVideos
                )
                return .none
            case .path(.element(_, action: .channelDetail(.unsubscribeResult(.success)))):
                if let last = state.path.last,
                   case .channelDetail(let detail) = last {
                    state.channels.remove(id: detail.channel.channelId)
                }
                _ = state.path.popLast()
                return .none
            case .refreshPendingDownloads:
                if state.selectedChannel != nil {
                    return .send(.channelDetail(.presented(.view(.viewDidAppear))))
                }
                return .none
            case .addChannel(.presented(.subscribeResult(.success))):
                return handleInternalAction(action, state: &state)
            case .alert(.presented(.confirmUnsubscribe(let channelId))):
                return handleConfirmedUnsubscribe(channelId, state: &state)
            case .alert:
                return .none
            case .videoDetail(.presented(.delegate(.didRequestMinimize))):
                state.videoDetail = nil
                return .none
            case .videoDetail:
                return .none
            case .addChannel, .channelDetail, .path:
                return .none
            default:
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
