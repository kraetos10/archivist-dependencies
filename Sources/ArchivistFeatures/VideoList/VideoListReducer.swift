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

public enum VideoListItem: Identifiable, Sendable, Equatable {
    case video(VideoResponse)
    case download(DownloadResponse)

    public var id: String {
        switch self {
        case .video(let video): video.videoId
        case .download(let download): download.youtubeId
        }
    }

    var publishedDate: Date? {
        switch self {
        case .video(let video):
            return video.publishedDate
        case .download(let download):
            if let published = download.published {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: published) {
                    return date
                }
                let dateOnly = DateFormatter()
                dateOnly.dateFormat = "yyyy-MM-dd"
                dateOnly.locale = Locale(identifier: "en_US_POSIX")
                if let date = dateOnly.date(from: published) {
                    return date
                }
            }
            if let timestamp = download.timestamp {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return nil
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
    public struct State: Sendable {
        var serverConfig: ServerConfig
        var videos: IdentifiedArrayOf<VideoResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var hasLoaded = false
        @Shared(.appStorage("videoListWatchFilter")) var watchFilter: WatchFilter = .unwatched
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
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<VideoResponse> = []
        var isSearching = false
        var useSplitView = false
        var selectedVideo: VideoDetailReducer.State?
        @Presents var presentedVideo: VideoDetailReducer.State?
        @Presents var videoDetail: VideoDetailReducer.State?
        var path = StackState<VideoListPath.State>()
        @Presents var playlistPicker: PlaylistPickerReducer.State?
        @Presents var addVideo: AddVideoReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        var isSearchActive: Bool {
            !searchQuery.isEmpty
        }

        var displayedVideos: [DisplayedVideo] {
            let filtered: IdentifiedArrayOf<VideoResponse>
            if isSearchActive {
                let localMatches = videos.filter {
                    $0.title.localizedCaseInsensitiveContains(searchQuery)
                }
                var merged = searchResults
                for video in localMatches {
                    merged.updateOrAppend(video)
                }
                filtered = merged
            } else {
                filtered = filteredVideos(for: watchFilter)
            }
            return filtered.map { video in
                DisplayedVideo(
                    video: video,
                    isDownloaded: downloadedVideoIDs.contains(video.videoId)
                )
            }
        }

        /// Raw filtered list for a single filter, used by the per-filter
        /// home sections (each section just takes the first N + a "View All"
        /// entry). The sort order mirrors whatever the user has selected
        /// for that filter's "View All" detail view (persisted via the
        /// same `videoListSortOrder_<filter>` app-storage key
        /// `FilteredVideoListReducer` reads).
        func items(for filter: WatchFilter) -> [DisplayedVideo] {
            let raw = filteredVideos(for: filter)
            let order = Self.savedSortOrder(for: filter)
            let sorted = Self.sort(raw, by: order)
            return sorted.map { video in
                DisplayedVideo(
                    video: video,
                    isDownloaded: downloadedVideoIDs.contains(video.videoId)
                )
            }
        }

        private static func savedSortOrder(for filter: WatchFilter) -> VideoSortOrder {
            let key = "videoListSortOrder_\(filter.rawValue)"
            if let raw = UserDefaults.standard.string(forKey: key),
               let value = VideoSortOrder(rawValue: raw) {
                return value
            }
            return .published
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
                var merged = videos.filter { downloadedVideoIDs.contains($0.videoId) }
                for video in downloadedVideos {
                    merged.updateOrAppend(video)
                }
                return merged
            }
        }

        /// Ordered list of sections the home screen renders (hides empty ones).
        static let homeSectionOrder: [WatchFilter] = [
            .continueWatching,
            .unwatched,
            .downloaded,
            .watched,
            .all
        ]
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case selectedVideoDetail(VideoDetailReducer.Action)
        case presentedVideo(PresentationAction<VideoDetailReducer.Action>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case path(StackActionOf<VideoListPath>)
        case playlistPicker(PresentationAction<PlaylistPickerReducer.Action>)
        case alert(PresentationAction<AlertAction>)
        case videosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        case contextDeleteResult(Result<String, Error>)
        case markWatchedResult(Result<String, Error>)
        case videoRefreshed(VideoResponse)
        case searchResult(Result<[VideoResponse], Error>)
        case downloadedVideosLoaded([VideoResponse])
        case addVideo(PresentationAction<AddVideoReducer.Action>)
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
            case splitViewEnabled
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

    nonisolated enum CancelID: Hashable, Sendable {
        case search
        case fetchVideos
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        coreReducer
            .ifLet(\.$playlistPicker, action: \.playlistPicker) {
                PlaylistPickerReducer()
            }
            .ifLet(\.$addVideo, action: \.addVideo) {
                AddVideoReducer()
            }
            .ifLet(\.$alert, action: \.alert)
            .ifLet(\.selectedVideo, action: \.selectedVideoDetail) {
                VideoDetailReducer()
            }
            .ifLet(\.$presentedVideo, action: \.presentedVideo) {
                VideoDetailReducer()
            }
            .ifLet(\.$videoDetail, action: \.videoDetail) {
                VideoDetailReducer()
            }
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
            case .selectedVideoDetail(.delegate(.didRequestMinimize)):
                state.selectedVideo = nil
                return .none
            case .selectedVideoDetail(.delegate(.didDismiss(let videoId))):
                state.selectedVideo = nil
                return refreshVideo(videoId: videoId, config: state.serverConfig)
            case .selectedVideoDetail(.serverDeleteResult(.success)):
                state.selectedVideo = nil
                return .send(.view(.pullToRefreshTriggered))
            case .selectedVideoDetail:
                return .none
            case .presentedVideo(.presented(.delegate(.didRequestMinimize))):
                state.presentedVideo = nil
                return .none
            case .presentedVideo(.presented(.delegate(.didDismiss(let videoId)))):
                state.presentedVideo = nil
                return refreshVideo(videoId: videoId, config: state.serverConfig)
            case .presentedVideo(.presented(.serverDeleteResult(.success))):
                state.presentedVideo = nil
                return .send(.view(.pullToRefreshTriggered))
            case .presentedVideo:
                return .none
            case .path(.element(_, action: .videoDetail(.delegate(.didDismiss(let videoId))))):
                _ = state.path.popLast()
                return refreshVideo(videoId: videoId, config: state.serverConfig)
            case .path(.element(_, action: .videoDetail(.serverDeleteResult(.success)))):
                _ = state.path.popLast()
                return .send(.view(.pullToRefreshTriggered))
            case .path(.element(_, action: .filteredList(.delegate(.videoSelected(let video))))):
                let detailState = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video
                )
                #if os(tvOS)
                state.path.append(.videoDetail(detailState))
                #else
                state.videoDetail = detailState
                #endif
                return .none
            case .path:
                return .none
            case .playlistPicker:
                return .none
            case .addVideo(.presented(.addResult(.success))):
                state.addVideo = nil
                return .send(.view(.pullToRefreshTriggered))
            case .addVideo:
                return .none
            case .alert:
                return .none
            case .videoDetail(.presented(.delegate(.didRequestMinimize))):
                state.videoDetail = nil
                return .none
            case .videoDetail(.presented(.delegate(.didDismiss(let videoId)))):
                state.videoDetail = nil
                return refreshVideo(videoId: videoId, config: state.serverConfig)
            case .videoDetail(.presented(.serverDeleteResult(.success))):
                state.videoDetail = nil
                return .send(.view(.pullToRefreshTriggered))
            case .videoDetail:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }

    private func refreshVideo(
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
