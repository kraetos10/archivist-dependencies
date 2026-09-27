import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

public struct DisplayedVideo: Identifiable, Sendable {
    public let video: VideoResponse
    public let isDownloaded: Bool

    public var id: String { video.videoId }
}

/// Pre-sorted slice of videos for one home page carousel. Cached on the
/// reducer's state so SwiftUI's body re-runs (image loads, scroll-driven
/// state mutations, `@FetchAll` updates) don't re-sort the full list on
/// every frame.
public struct HomeSectionVideos: Equatable, Sendable, Identifiable {
    public let filter: WatchFilter
    public let videos: [VideoResponse]
    public var id: WatchFilter { filter }
}

public enum VideoListItem: Identifiable, Sendable, Equatable {
    case video(VideoResponse)
    case download(DownloadResponse)

    public var id: String {
        switch self {
        case .video(let video): video.videoId
        case .download(let download): download.youtubeId
        }
    }

    /// Used as a sort key, so it goes through `PublishedDate`'s shared
    /// format styles rather than building formatters on every comparison.
    var publishedDate: Date? {
        switch self {
        case .video(let video):
            video.publishedDate
        case .download(let download):
            PublishedDate.date(from: download.published)
                ?? download.timestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        }
    }

    var isWatched: Bool {
        switch self {
        case .video(let video):
            video.isWatched
        case .download: false
        }
    }
}

@Reducer
public struct VideoListReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var videos: IdentifiedArrayOf<VideoResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var hasLoaded = false
        @Shared(.videoListWatchFilter) var watchFilter
        @Shared(.childModeEnabled) public var childModeEnabled
        /// Home page always fetches by published date; per-filter sort is
        /// owned by the "View All" detail view now.
        let sortOrder: VideoSortOrder = .published
        @FetchAll(
            DeviceDownload
                .where { $0.status.eq(DeviceDownloadStatus.completed) }
        )
        var completedDownloads

        var downloadedVideoIDs: Set<String> {
            Set(completedDownloads.map(\.id))
        }
        var downloadedVideos: IdentifiedArrayOf<VideoResponse> = []
        /// Sorted+capped slice for each home carousel. Recomputed only by
        /// `recomputeHomeSections()` on data-changing actions; reading it
        /// from the view costs an array index, not a sort.
        var cachedHomeSections: [HomeSectionVideos] = []
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<VideoResponse> = []
        var isSearching = false
        var path = StackState<VideoListPath.State>()
        /// Whatever is presented over the home screen. Only one at a time:
        /// the video (iOS — tvOS pushes it onto `path`), the playlist
        /// picker, the add-video form or an error.
        @Presents var destination: Destination.State?

        var isSearchActive: Bool {
            !searchQuery.isEmpty
        }

        var displayedVideos: [DisplayedVideo] {
            let filtered: IdentifiedArrayOf<VideoResponse>
            if isSearchActive {
                let localMatches = videos.filter {
                    $0.title.localizedStandardContains(searchQuery)
                }
                var merged = searchResults
                for video in localMatches {
                    merged.updateOrAppend(video)
                }
                filtered = merged
            } else {
                filtered = filteredVideos(for: watchFilter)
            }
            let downloadedIDs = downloadedVideoIDs
            return filtered.map { video in
                DisplayedVideo(
                    video: video,
                    isDownloaded: downloadedIDs.contains(video.videoId)
                )
            }
        }

        /// Raw filtered list for a single filter, used by the per-filter
        /// home sections (each section just takes the first N + a "View All"
        /// entry). The sort order mirrors whatever the user has selected
        /// for that filter's "View All" detail view (the same
        /// `.videoListSortOrder(for:)` key `FilteredVideoListReducer` writes).
        ///
        /// Reads from `cachedHomeSections` so the home view never sorts
        /// during scroll — only the `isDownloaded` decoration runs (a
        /// Set lookup per card).
        func items(for filter: WatchFilter) -> [DisplayedVideo] {
            let cached = cachedHomeSections.first(where: { $0.filter == filter })?.videos ?? []
            let downloadedIDs = downloadedVideoIDs
            return cached.map { video in
                DisplayedVideo(
                    video: video,
                    isDownloaded: downloadedIDs.contains(video.videoId)
                )
            }
        }

        /// Recompute the cached home sections from the current `videos`
        /// + per-filter sort order. Call after any mutation to `videos`
        /// — pagination append, single-video refresh, server delete — and
        /// when a "View All" screen changes its sort.
        mutating func recomputeHomeSections() {
            cachedHomeSections = Self.homeSectionOrder.map { filter in
                let raw = filteredVideos(for: filter)
                @Shared(.videoListSortOrder(for: filter)) var order
                let sorted = Self.sort(raw, by: order)
                return HomeSectionVideos(
                    filter: filter,
                    videos: Array(sorted.prefix(Self.homeSectionItemCap))
                )
            }
        }

        private static func sort(
            _ videos: IdentifiedArrayOf<VideoResponse>,
            by order: VideoSortOrder
        ) -> IdentifiedArrayOf<VideoResponse> {
            // `.continueWatching` is sorted by watched-date in
            // `filteredVideos(for:)` already; don't override that for the
            // home preview.
            let array = Array(videos)
            let sorted: [VideoResponse]
            switch order {
            case .published:
                sorted = array.sorted {
                    ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast)
                }
            case .downloaded:
                sorted = array.sorted {
                    ($0.dateDownloaded ?? 0) > ($1.dateDownloaded ?? 0)
                }
            case .views:
                sorted = array.sorted {
                    ($0.stats?.viewCount ?? 0) > ($1.stats?.viewCount ?? 0)
                }
            case .likes:
                sorted = array.sorted {
                    ($0.stats?.likeCount ?? 0) > ($1.stats?.likeCount ?? 0)
                }
            case .duration:
                sorted = array.sorted {
                    ($0.player?.duration ?? 0) > ($1.player?.duration ?? 0)
                }
            case .mediasize:
                sorted = array.sorted {
                    ($0.mediaSize ?? 0) > ($1.mediaSize ?? 0)
                }
            }
            return IdentifiedArrayOf(uniqueElements: sorted)
        }

        private func filteredVideos(for filter: WatchFilter) -> IdentifiedArrayOf<VideoResponse> {
            switch filter {
            case .all:
                return videos
            case .unwatched:
                return videos.filter { $0.isUnwatched }
            case .continueWatching:
                // Most recently watched first — `watchedDate` is bumped by the
                // server each time we post a progress update.
                let sorted = videos
                    .filter { $0.isPartiallyWatched }
                    .sorted { ($0.player?.watchedDate ?? 0) > ($1.player?.watchedDate ?? 0) }
                return IdentifiedArrayOf(uniqueElements: sorted)
            case .watched:
                return videos.filter { $0.isWatched }
            case .downloaded:
                let downloadedIDs = downloadedVideoIDs
                var merged = videos.filter { downloadedIDs.contains($0.videoId) }
                for video in downloadedVideos {
                    merged.updateOrAppend(video)
                }
                return merged
            }
        }

        /// Ordered list of sections the home screen renders (hides empty ones).
        /// `.downloaded` (the on-device row) is intentionally omitted —
        /// the same content already lives on the dedicated Downloads
        /// settings screen, and surfacing it on the home page bloats
        /// the carousel without adding new info.
        static let homeSectionOrder: [WatchFilter] = [
            .continueWatching,
            .unwatched,
            .watched,
            .all
        ]

        /// Per-section cap held by the home cache. Larger than the carousel's
        /// visible cap so the cache stays valid even if the visible cap is
        /// bumped, while still bounding the sort cost.
        static let homeSectionItemCap = 20
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    @Reducer
    public enum Destination {
        case addVideo(AddVideoReducer)
        case alert(AlertState<AlertAction>)
        case playlistPicker(PlaylistPickerReducer)
        case videoDetail(VideoDetailReducer)
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case path(StackActionOf<VideoListPath>)
        /// Entry points for parents (tvOS Search's context menu): the same
        /// server writes the home screen's context menu performs.
        case markAsWatched(VideoResponse)
        case deleteFromServer(VideoResponse)
        case videosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        case contextDeleteResult(Result<String, Error>)
        case markWatchedResult(Result<String, Error>)
        case videoRefreshed(VideoResponse)
        case searchResult(Result<[VideoResponse], Error>)
        case downloadedVideosLoaded([VideoResponse])
        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case videoTapped(VideoResponse)
            case downloadToDeviceTapped(VideoResponse)
            case deleteFromDeviceTapped(VideoResponse)
            case deleteFromServerTapped(VideoResponse)
            case watchFilterChanged(WatchFilter)
            case addToPlaylistTapped(VideoResponse)
            case markAsWatchedTapped(VideoResponse)
            case playNextTapped(VideoResponse)
            case addVideoTapped
            case viewAllTapped(WatchFilter)
        }
    }

    @Dependency(\.videoService) var videoService
    @Dependency(\.searchService) var searchService
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.localVideoStorage) var localVideoStorage
    @Dependency(\.continuousClock) var clock
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.playNextDatabase) var playNextDatabase
    @Dependency(\.topShelf) var topShelf
    @Dependency(\.date.now) var now

    nonisolated enum CancelID: Hashable, Sendable {
        case search
        /// Every page fetch, refresh included. A refresh cancels an
        /// in-flight page so its response can't land in the fresh list.
        case fetchVideos
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        coreReducer
            .ifLet(\.$destination, action: \.destination)
            .forEach(\.path, action: \.path)
    }

    @ReducerBuilder<State, Action>
    private var coreReducer: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .binding(\.searchQuery):
                return handleSearchQueryChanged(state: &state)
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .path(let pathAction):
                return handlePathAction(pathAction, state: &state)
            case .markAsWatched(let video):
                return handleMarkAsWatched(video, state: &state)
            case .deleteFromServer(let video):
                return handleDeleteFromServer(video, state: &state)
            case .destination(.presented(.addVideo(.addResult(.success)))):
                state.destination = nil
                return handleRefreshTriggered(state: &state)
            case .destination(.presented(.videoDetail(.delegate(.didRequestMinimize)))):
                state.destination = nil
                return .none
            case .destination(.presented(.videoDetail(.delegate(.didDismiss(let videoId))))):
                state.destination = nil
                return refreshVideo(videoId: videoId, config: state.serverConfig)
            case .destination(.presented(.videoDetail(.serverDeleteResult(.success)))):
                state.destination = nil
                return handleRefreshTriggered(state: &state)
            case .destination:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }

    /// The navigation stack: video detail (tvOS) and the "View All" lists,
    /// whose context-menu requests run through this reducer's handlers.
    private func handlePathAction(
        _ action: StackActionOf<VideoListPath>,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .element(_, action: .videoDetail(.delegate(.didDismiss(let videoId)))):
            _ = state.path.popLast()
            return refreshVideo(videoId: videoId, config: state.serverConfig)
        case .element(_, action: .videoDetail(.serverDeleteResult(.success))):
            _ = state.path.popLast()
            return handleRefreshTriggered(state: &state)
        case .element(_, action: .filteredList(.delegate(let delegate))):
            return handleFilteredListDelegate(delegate, state: &state)
        case .element(_, action: .filteredList(.view(.sortOrderChanged))):
            // The home carousels follow each "View All" screen's sort.
            state.recomputeHomeSections()
            return .none
        default:
            return .none
        }
    }

    private func handleFilteredListDelegate(
        _ delegate: FilteredVideoListReducer.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch delegate {
        case .videoSelected(let video):
            let detailState = VideoDetailReducer.State(
                serverConfig: state.serverConfig,
                video: video
            )
            #if os(tvOS)
            state.path.append(.videoDetail(detailState))
            #else
            state.destination = .videoDetail(detailState)
            #endif
            return .none
        case .playNextRequested(let video):
            return handleViewAction(.playNextTapped(video), state: &state)
        case .addToPlaylistRequested(let video):
            return handleViewAction(.addToPlaylistTapped(video), state: &state)
        case .downloadToDeviceRequested(let video):
            return handleViewAction(.downloadToDeviceTapped(video), state: &state)
        case .deleteFromDeviceRequested(let video):
            return handleViewAction(.deleteFromDeviceTapped(video), state: &state)
        case .markAsWatchedRequested(let video):
            return handleMarkAsWatched(video, state: &state)
        case .deleteFromServerRequested(let video):
            return handleDeleteFromServer(video, state: &state)
        }
    }

    func refreshVideo(
        videoId: String,
        config: ServerConfig
    ) -> Effect<Action> {
        .run { [videoService] send in
            if let video = try? await videoService.getVideo(config: config, id: videoId) {
                await send(.videoRefreshed(video))
            }
        }
    }
}

extension VideoListReducer.Destination.State: Equatable, Sendable {}
