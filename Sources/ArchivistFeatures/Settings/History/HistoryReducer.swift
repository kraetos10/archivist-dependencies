import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct HistoryReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var continueVideos: IdentifiedArrayOf<VideoResponse> = []
        var watchedVideos: IdentifiedArrayOf<VideoResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var hasLoaded = false
    }

    public enum Action: ViewAction {
        case view(View)
        case delegate(Delegate)
        case continueVideosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        case watchedVideosResult(Result<PaginatedResponse<VideoResponse>, Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case videoTapped(VideoResponse)
        }

        public enum Delegate: Equatable, Sendable {
            case videoSelected(VideoResponse)
        }
    }

    @Dependency(\.videoService) var videoService

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .delegate:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
