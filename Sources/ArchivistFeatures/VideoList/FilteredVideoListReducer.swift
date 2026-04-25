import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

/// Paginated "View All" destination pushed from the home page when the user
/// taps a filter's "View All" button. Self-contained: hits `/api/video/` with
/// the filter's API value and paginates on scroll.
@Reducer
public struct FilteredVideoListReducer {
    public init() {}

    @ObservableState
    public struct State: Sendable {
        public var serverConfig: ServerConfig
        public var filter: WatchFilter
        public var videos: IdentifiedArrayOf<VideoResponse> = []
        public var currentPage: Int = 1
        public var lastPage: Int = 1
        public var isLoading = false
        public var isLoadingMore = false
        public var hasLoaded = false
        public var searchQuery: String = ""
        /// Sort persists per filter so "Watched" can be ordered differently
        /// than "Unwatched" without the two overwriting each other.
        @Shared public var sortOrder: VideoSortOrder
        @FetchAll(
            DeviceDownload
                .where { $0.status.eq(DeviceDownloadStatus.completed) }
        )
        var completedDownloads

        public init(serverConfig: ServerConfig, filter: WatchFilter) {
            self.serverConfig = serverConfig
            self.filter = filter
            // KVO can't observe defaults keys containing "." — substitute
            // an underscore so cross-process observation stays efficient.
            _sortOrder = Shared(
                wrappedValue: .published,
                .appStorage("videoListSortOrder_\(filter.rawValue)")
            )
        }

        var downloadedVideoIDs: Set<String> {
            Set(completedDownloads.map(\.id))
        }

        /// Videos filtered for this destination's `filter`. Some filters
        /// (`.continueWatching`, `.downloaded`) have no matching API value and
        /// are derived client-side from the full paginated list.
        var displayedVideos: [DisplayedVideo] {
            let filtered: IdentifiedArrayOf<VideoResponse>
            switch filter {
            case .all:
                filtered = videos
            case .unwatched:
                filtered = videos.filter { $0.isUnwatched }
            case .continueWatching:
                filtered = videos.filter { $0.isPartiallyWatched }
            case .watched:
                filtered = videos.filter { $0.isWatched }
            case .downloaded:
                filtered = videos.filter { downloadedVideoIDs.contains($0.videoId) }
            }
            let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
            let searched: IdentifiedArrayOf<VideoResponse> = trimmed.isEmpty
                ? filtered
                : filtered.filter {
                    $0.title.localizedCaseInsensitiveContains(trimmed)
                    || ($0.channelName.localizedCaseInsensitiveContains(trimmed))
                }
            return searched.map { video in
                DisplayedVideo(
                    video: video,
                    isDownloaded: downloadedVideoIDs.contains(video.videoId)
                )
            }
        }
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case videosResult(Result<PaginatedResponse<VideoResponse>, Error>)

        public enum Delegate: Equatable, Sendable {
            case videoSelected(VideoResponse)
        }

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case videoTapped(VideoResponse)
            case sortOrderChanged(VideoSortOrder)
        }
    }

    @Dependency(\.videoService) var videoService

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
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
