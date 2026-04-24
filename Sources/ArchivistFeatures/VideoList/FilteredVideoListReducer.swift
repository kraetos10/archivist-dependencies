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
        @Shared(.appStorage("videoListSortOrder")) public var sortOrder: VideoSortOrder = .published
        @FetchAll(
            DeviceDownload
                .where { $0.status.eq(DeviceDownloadStatus.completed) }
        )
        var completedDownloads

        public init(serverConfig: ServerConfig, filter: WatchFilter) {
            self.serverConfig = serverConfig
            self.filter = filter
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
            case .videosResult(.success(let response)):
                for video in response.data {
                    state.videos.updateOrAppend(video)
                }
                state.currentPage = response.paginate.currentPage
                state.lastPage = response.paginate.lastPage
                state.isLoading = false
                state.isLoadingMore = false
                state.hasLoaded = true

                // Mirror the channel-detail trick: if client-side filtering
                // thinned the page below the server's page size, eagerly pull
                // the next page so the user isn't left with a sparse list.
                if state.displayedVideos.count < response.paginate.pageSize,
                   state.currentPage < state.lastPage,
                   !state.isLoadingMore {
                    state.isLoadingMore = true
                    return fetchPage(state.currentPage + 1, state: &state)
                }
                return .none
            case .videosResult(.failure):
                state.isLoading = false
                state.isLoadingMore = false
                state.hasLoaded = true
                return .none
            }
        }
    }

    private func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            guard !state.hasLoaded, !state.isLoading else { return .none }
            return fetchPage(1, state: &state)
        case .pullToRefreshTriggered:
            state.videos = []
            state.currentPage = 1
            state.lastPage = 1
            state.hasLoaded = false
            return fetchPage(1, state: &state)
        case .lastItemAppeared:
            guard state.currentPage < state.lastPage,
                  !state.isLoading,
                  !state.isLoadingMore else { return .none }
            state.isLoadingMore = true
            return fetchPage(state.currentPage + 1, state: &state)
        case .videoTapped(let video):
            return .send(.delegate(.videoSelected(video)))
        case .sortOrderChanged(let sort):
            guard sort != state.sortOrder else { return .none }
            state.$sortOrder.withLock { $0 = sort }
            state.videos = []
            state.currentPage = 1
            state.lastPage = 1
            state.hasLoaded = false
            return fetchPage(1, state: &state)
        }
    }

    private func fetchPage(
        _ page: Int,
        state: inout State
    ) -> Effect<Action> {
        if page == 1 { state.isLoading = true }
        let config = state.serverConfig
        let sort = state.sortOrder.apiValue
        let watch = state.filter.apiValue
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: page,
                    sort: sort,
                    order: "desc",
                    type: nil,
                    watch: watch,
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }
}
