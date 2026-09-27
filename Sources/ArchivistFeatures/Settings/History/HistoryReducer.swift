import ArchivistComponents
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
        /// The two lists load independently; one finishing says nothing
        /// about the other.
        var isLoadingContinue = false
        var isLoadingWatched = false
        var isLoadingMore = false
        var hasLoaded = false

        var isLoading: Bool {
            isLoadingContinue || isLoadingWatched
        }

        var showsPlaceholders: Bool {
            isLoading && !hasLoaded
        }

        var showsEmptyState: Bool {
            hasLoaded && !isLoading && continueVideos.isEmpty && watchedVideos.isEmpty
        }

        var continueRows: [HistoryRow] {
            continueVideos.map { HistoryRow(video: $0, config: serverConfig) }
        }

        var watchedRows: [HistoryRow] {
            watchedVideos.map { HistoryRow(video: $0, config: serverConfig) }
        }

        init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
        }
    }

    public enum Action: ViewAction {
        case view(View)
        case delegate(Delegate)
        case continueVideosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        /// `page` travels with the result: page one replaces the list,
        /// later pages append — regardless of what else finished first.
        case watchedVideosResult(page: Int, Result<PaginatedResponse<VideoResponse>, Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case itemAppeared(String)
            case videoTapped(VideoResponse)
        }

        public enum Delegate: Equatable, Sendable {
            case videoSelected(VideoResponse)
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        case continueVideos
        case watchedVideos
    }

    @Dependency(\.videoService) var videoService

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .continueVideosResult(let result):
                return handleContinueVideosResult(result, state: &state)
            case .watchedVideosResult(let page, let result):
                return handleWatchedVideosResult(page: page, result, state: &state)
            case .delegate:
                return .none
            }
        }
    }
}

/// One row of the compact history list, with its display text worked out.
struct HistoryRow: Equatable, Identifiable {
    let video: VideoResponse
    let viewCountText: String?
    let thumbnailURL: URL?

    var id: String { video.id }

    init(
        video: VideoResponse,
        config: ServerConfig
    ) {
        self.video = video
        self.viewCountText = video.formattedViewCount.map {
            String.localised("video.viewCount \($0)", table: .videos)
        }
        self.thumbnailURL = video.vidThumbUrl.flatMap { config.fullURL(for: $0) }
    }
}
