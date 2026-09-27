#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct TVSearchReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var searchQuery: String = ""
        var videoResults: [VideoResponse] = []
        var channelResults: [ChannelResponse] = []
        var playlistResults: [PlaylistResponse] = []
        var isSearching = false
        var hasSearched = false
        var lastSearchedQuery: String = ""
        /// The cover over the results: a video, a channel or a playlist.
        /// Channels and playlists open over the Search tab itself, not
        /// through the home screen's covers — those aren't on screen while
        /// Search is the selected tab.
        @Presents var destination: Destination.State?
        /// A video opened from inside the channel or playlist cover. Not a
        /// `destination` case: it's presented over that cover, alongside
        /// it, rather than instead of it.
        @Presents var nestedVideoDetail: VideoDetailReducer.State?

        var hasNoResults: Bool {
            hasSearched
                && videoResults.isEmpty
                && channelResults.isEmpty
                && playlistResults.isEmpty
        }
    }

    @Reducer
    public enum Destination {
        case channelDetail(ChannelDetailReducer)
        case playlistDetail(PlaylistDetailReducer)
        case videoDetail(VideoDetailReducer)
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        /// The typing pause after a query change has elapsed; run the search.
        case searchDebounceElapsed
        case searchResult(Result<SearchResponse, Error>)
        case destination(PresentationAction<Destination.Action>)
        case nestedVideoDetail(PresentationAction<VideoDetailReducer.Action>)
        /// A video changed elsewhere (marked watched from a result's
        /// context menu), so its result card shows the new state.
        case videoUpdated(VideoResponse)
        /// A server download finished; an open channel reloads its list.
        case refreshPendingDownloads

        @CasePathable
        public enum View {
            case videoTapped(VideoResponse)
            case channelTapped(ChannelResponse)
            case playlistTapped(PlaylistResponse)
            case markAsWatchedTapped(VideoResponse)
            case deleteFromServerTapped(VideoResponse)
        }

        public enum Delegate: Equatable, Sendable {
            /// The parent owns the server write — the same one the home
            /// screen's context menu uses.
            case markAsWatchedRequested(VideoResponse)
            case deleteFromServerRequested(VideoResponse)
        }
    }

    enum CancelID { case search }

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
            case .destination(.presented(.videoDetail(.delegate(.didRequestMinimize)))),
                 .destination(.presented(.videoDetail(.delegate(.didDismiss)))):
                state.destination = nil
                return .none
            case .destination(.presented(.channelDetail(.delegate(.videoSelected(let video, let nextVideos))))):
                return handleChannelVideoSelected(
                    video,
                    nextVideos: nextVideos,
                    state: &state
                )
            case .destination(.presented(.playlistDetail(.delegate(
                .showVideo(let video, let nextVideos, let loopVideoIds)
            )))):
                return handlePlaylistVideoSelected(
                    video,
                    nextVideos: nextVideos,
                    loopVideoIds: loopVideoIds,
                    state: &state
                )
            case .destination(.presented(.channelDetail(.delegate(.didUnsubscribe)))),
                 .destination(.presented(.playlistDetail(.delegate(.didUnsubscribe)))):
                state.destination = nil
                return .none
            case .destination:
                return .none
            case .nestedVideoDetail(.presented(.delegate(.didRequestMinimize))),
                 .nestedVideoDetail(.presented(.delegate(.didDismiss))):
                state.nestedVideoDetail = nil
                return .none
            case .nestedVideoDetail:
                return .none
            case .delegate:
                return .none
            case .searchDebounceElapsed:
                return handleSearch(state: &state)
            case .searchResult(let result):
                return handleSearchResult(result, state: &state)
            case .videoUpdated(let video):
                return handleVideoUpdated(video, state: &state)
            case .refreshPendingDownloads:
                return handleRefreshPendingDownloads(state: &state)
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$nestedVideoDetail, action: \.nestedVideoDetail) {
            VideoDetailReducer()
        }
    }
}

extension TVSearchReducer.Destination.State: Equatable, Sendable {}
#endif
