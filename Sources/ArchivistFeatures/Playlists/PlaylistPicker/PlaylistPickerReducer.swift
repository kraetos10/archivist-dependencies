import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct PlaylistPickerReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var videoId: String
        var playlists: IdentifiedArrayOf<PlaylistResponse> = []
        var alreadyInPlaylistIds: Set<String> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var isAdding = false
        @Presents var alert: AlertState<AlertAction>?

        func isAlreadyAdded(_ playlist: PlaylistResponse) -> Bool {
            alreadyInPlaylistIds.contains(playlist.playlistId)
        }
    }

    /// One page of custom playlists, with the ids of those that already
    /// hold the video.
    public struct Page: Equatable, Sendable {
        let playlists: [PlaylistResponse]
        let containingVideo: Set<String>
        let currentPage: Int
        let lastPage: Int
    }

    public enum AlertAction: Equatable, Sendable {}

    public enum Action: ViewAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case loadResult(Result<Page, Error>)
        case addResult(Result<Void, Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case lastItemAppeared
            case playlistTapped(PlaylistResponse)
        }
    }

    /// How many playlists are checked for the video at once.
    static let membershipCheckConcurrency = 6

    @Dependency(\.playlistService) var playlistService
    @Dependency(\.dismiss) var dismiss

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .alert:
                return .none
            case .loadResult, .addResult:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
