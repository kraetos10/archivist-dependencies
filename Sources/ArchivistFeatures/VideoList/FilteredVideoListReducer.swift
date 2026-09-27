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
    public struct State: Equatable, Sendable {
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
            _sortOrder = Shared(.videoListSortOrder(for: filter))
        }

        var downloadedVideoIDs: Set<String> {
            Set(completedDownloads.map(\.id))
        }

        /// Videos filtered for this destination's `filter`. Some filters
        /// (`.continueWatching`, `.downloaded`) have no matching API value and
        /// are derived client-side from the full paginated list.
        var displayedVideos: [DisplayedVideo] {
            // Built once: the computed property makes a new Set per access.
            let downloadedVideoIDs = downloadedVideoIDs
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
                    $0.title.localizedStandardContains(trimmed)
                    || $0.channelName.localizedStandardContains(trimmed)
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
            // Forwarded to the parent `VideoListReducer` so the existing
            // context-menu handlers (download, watched, playlist, etc.)
            // run with their full set of dependencies, instead of
            // duplicating that surface here.
            case playNextRequested(VideoResponse)
            case addToPlaylistRequested(VideoResponse)
            case downloadToDeviceRequested(VideoResponse)
            case deleteFromDeviceRequested(VideoResponse)
            case markAsWatchedRequested(VideoResponse)
            case deleteFromServerRequested(VideoResponse)
        }

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case videoTapped(VideoResponse)
            case sortOrderChanged(VideoSortOrder)
            case playNextTapped(VideoResponse)
            case addToPlaylistTapped(VideoResponse)
            case downloadToDeviceTapped(VideoResponse)
            case deleteFromDeviceTapped(VideoResponse)
            case markAsWatchedTapped(VideoResponse)
            case deleteFromServerTapped(VideoResponse)
        }
    }

    @Dependency(\.videoService) var videoService

    enum CancelID {
        /// Every page fetch. A refresh or re-sort cancels a page still in
        /// flight, so a response for the old sort can't merge into the new
        /// list.
        case fetch
    }

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
