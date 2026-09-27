import ArchivistNetworking
import ComposableArchitecture
import Foundation

/// What the playlist list shows. Worked out once per read so the view only
/// switches on it, and so the search merge runs a single time.
public enum PlaylistsContent: Equatable, Sendable {
    case placeholders
    case noPlaylists
    case noSearchResults
    case playlists(IdentifiedArrayOf<PlaylistResponse>)
}

@Reducer
public struct PlaylistsReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var playlists: IdentifiedArrayOf<PlaylistResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var hasLoaded = false
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<PlaylistResponse> = []
        var isSearching = false
        var useSplitView = false
        @Shared(.autoPlayPlaylist) var autoPlayPlaylist
        @Presents var addPlaylist: AddPlaylistReducer.State?
        @Presents var videoDetail: VideoDetailReducer.State?
        /// The detail shown beside the list in split view (iPad), or
        /// presented over the tvOS home screen. Never set alongside a `path`
        /// push — a playlist detail has exactly one home.
        @Presents var selectedPlaylist: PlaylistDetailReducer.State?
        // Stack navigation (iPhone, tvOS "All playlists")
        var path = StackState<PlaylistsPath.State>()

        var isSearchActive: Bool {
            !searchQuery.isEmpty
        }

        var filteredPlaylists: IdentifiedArrayOf<PlaylistResponse> {
            guard isSearchActive else { return playlists }
            let localMatches = playlists.filter {
                $0.playlistName.localizedStandardContains(searchQuery)
            }
            var merged = searchResults
            for playlist in localMatches {
                merged.updateOrAppend(playlist)
            }
            return merged
        }

        var content: PlaylistsContent {
            let filtered = filteredPlaylists
            guard filtered.isEmpty else { return .playlists(filtered) }
            if hasLoaded {
                return searchQuery.isEmpty ? .noPlaylists : .noSearchResults
            }
            return isLoading ? .placeholders : .playlists([])
        }
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case playlistsResult(Result<PaginatedResponse<PlaylistResponse>, Error>)
        case searchResult(Result<[PlaylistResponse], Error>)
        case playlistDetail(PresentationAction<PlaylistDetailReducer.Action>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case path(StackActionOf<PlaylistsPath>)
        case addPlaylist(PresentationAction<AddPlaylistReducer.Action>)

        @CasePathable
        public enum View {
            case viewDidAppear
            /// The iPad split view appeared: switch to split-view selection
            /// and load, in one step.
            case splitViewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case playlistCardTapped(PlaylistResponse)
            case addPlaylistTapped
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        case search
        case load
    }

    @Dependency(\.playlistService) var playlistService
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
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$addPlaylist, action: \.addPlaylist) {
            AddPlaylistReducer()
        }
        .ifLet(\.$selectedPlaylist, action: \.playlistDetail) {
            PlaylistDetailReducer()
        }
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
        .forEach(\.path, action: \.path)
    }
}
