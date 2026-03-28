import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct PlaylistsReducer {
    public init() {}
    @ObservableState
    public struct State: Sendable {
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
        @Presents var addPlaylist: AddPlaylistReducer.State?
        @Presents var videoDetail: VideoDetailReducer.State?
        // Split view (iPad)
        @Presents var selectedPlaylist: PlaylistDetailReducer.State?
        // Stack navigation (iPhone)
        var path = StackState<PlaylistsPath.State>()

        var isSearchActive: Bool {
            !searchQuery.isEmpty
        }

        var filteredPlaylists: IdentifiedArrayOf<PlaylistResponse> {
            guard isSearchActive else { return playlists }
            let localMatches = playlists.filter {
                $0.playlistName.localizedCaseInsensitiveContains(searchQuery)
            }
            var merged = searchResults
            for playlist in localMatches {
                merged.updateOrAppend(playlist)
            }
            return merged
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
            case pullToRefreshTriggered
            case lastItemAppeared
            case playlistCardTapped(PlaylistResponse)
            case addPlaylistTapped
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        case search
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
            case .addPlaylist(.presented(.subscribeResult(.success))),
                 .addPlaylist(.presented(.createCustomResult(.success))):
                return handleInternalAction(action, state: &state)
            case .playlistDetail(.presented(.unsubscribeResult(.success))):
                if let playlistId = state.selectedPlaylist?.playlist.playlistId {
                    state.playlists.remove(id: playlistId)
                }
                state.selectedPlaylist = nil
                return .none
            case .path(.element(_, action: .playlistDetail(.unsubscribeResult(.success)))):
                if let last = state.path.last,
                   case .playlistDetail(let detail) = last {
                    state.playlists.remove(id: detail.playlist.playlistId)
                }
                _ = state.path.popLast()
                return .none
            case .path(.element(_, action: .playlistDetail(.delegate(.showVideo(let video, let nextVideos))))):
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: nextVideos,
                    showPlayNext: false
                )
                return .none
            case .playlistDetail(.presented(.delegate(.showVideo(let video, let nextVideos)))):
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: nextVideos,
                    showPlayNext: false
                )
                return .none
            case .videoDetail(.presented(.delegate(.didRequestMinimize))):
                state.videoDetail = nil
                return .none
            case .videoDetail:
                return .none
            case .path, .addPlaylist, .playlistDetail:
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
