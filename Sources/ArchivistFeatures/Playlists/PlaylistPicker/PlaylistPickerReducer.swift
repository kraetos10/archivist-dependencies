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
        var playlists: [PlaylistResponse] = []
        var alreadyInPlaylistIds: Set<String> = []
        var isLoading = false
        var isAdding = false
    }

    public enum Action: ViewAction {
        case view(View)
        case playlistsLoaded([PlaylistResponse], Set<String>)
        case loadFailed
        case addSucceeded
        case addFailed

        @CasePathable
        public enum View {
            case viewDidAppear
            case playlistTapped(PlaylistResponse)
        }
    }

    @Dependency(\.playlistService) var playlistService
    @Dependency(\.dismiss) var dismiss

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
