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
        @Presents var videoDetail: VideoDetailReducer.State?
        /// Channels and playlists open over the Search tab itself, not
        /// through the home screen's covers — those aren't on screen while
        /// Search is the selected tab.
        @Presents var channelDetail: ChannelDetailReducer.State?
        @Presents var playlistDetail: PlaylistDetailReducer.State?
        /// A video opened from inside `channelDetail` or `playlistDetail`.
        /// Kept apart from `videoDetail` because it's presented over those
        /// covers rather than over the results.
        @Presents var nestedVideoDetail: VideoDetailReducer.State?

        var hasNoResults: Bool {
            hasSearched
                && videoResults.isEmpty
                && channelResults.isEmpty
                && playlistResults.isEmpty
        }
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case searchResult(Result<SearchResponse, Error>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case channelDetail(PresentationAction<ChannelDetailReducer.Action>)
        case playlistDetail(PresentationAction<PlaylistDetailReducer.Action>)
        case nestedVideoDetail(PresentationAction<VideoDetailReducer.Action>)
        /// A video changed elsewhere (marked watched from a result's
        /// context menu), so its result card shows the new state.
        case videoUpdated(VideoResponse)
        /// A server download finished; an open channel reloads its list.
        case refreshPendingDownloads

        @CasePathable
        public enum View {
            case searchSubmitted
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
            case .videoDetail(.presented(.delegate(.didRequestMinimize))),
                 .videoDetail(.presented(.delegate(.didDismiss))):
                state.videoDetail = nil
                return .none
            case .videoDetail:
                return .none
            case .channelDetail(.presented(.delegate(.videoSelected(let video, let nextVideos)))):
                return handleChannelVideoSelected(
                    video,
                    nextVideos: nextVideos,
                    state: &state
                )
            case .channelDetail(.presented(.unsubscribeResult(.success))):
                state.channelDetail = nil
                return .none
            case .channelDetail:
                return .none
            case .playlistDetail(.presented(.delegate(
                .showVideo(let video, let nextVideos, let loopVideoIds)
            ))):
                return handlePlaylistVideoSelected(
                    video,
                    nextVideos: nextVideos,
                    loopVideoIds: loopVideoIds,
                    state: &state
                )
            case .playlistDetail(.presented(.unsubscribeResult(.success))):
                state.playlistDetail = nil
                return .none
            case .playlistDetail:
                return .none
            case .nestedVideoDetail(.presented(.delegate(.didRequestMinimize))),
                 .nestedVideoDetail(.presented(.delegate(.didDismiss))):
                state.nestedVideoDetail = nil
                return .none
            case .nestedVideoDetail:
                return .none
            case .delegate:
                return .none
            case .searchResult(let result):
                return handleSearchResult(result, state: &state)
            case .videoUpdated(let video):
                return handleVideoUpdated(video, state: &state)
            case .refreshPendingDownloads:
                return handleRefreshPendingDownloads(state: &state)
            }
        }
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
        .ifLet(\.$channelDetail, action: \.channelDetail) {
            ChannelDetailReducer()
        }
        .ifLet(\.$playlistDetail, action: \.playlistDetail) {
            PlaylistDetailReducer()
        }
        .ifLet(\.$nestedVideoDetail, action: \.nestedVideoDetail) {
            VideoDetailReducer()
        }
    }
}
#endif
