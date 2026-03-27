import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum VideoListItem: Identifiable, Sendable, Equatable {
    case video(VideoResponse)
    case download(DownloadResponse)

    public var id: String {
        switch self {
        case .video(let v): v.videoId
        case .download(let d): d.youtubeId
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
        case .video(let v):
            v.isWatched
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
        var watchFilter: WatchFilter = .unwatched
        var showDownloadedOnly = false
        var downloadedVideoIDs: Set<String> = []
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

        var displayedVideos: IdentifiedArrayOf<VideoResponse> {
            if isSearchActive {
                let localMatches = videos.filter {
                    $0.title.localizedCaseInsensitiveContains(searchQuery)
                }
                var merged = searchResults
                for video in localMatches {
                    merged.updateOrAppend(video)
                }
                return merged
            }
            if showDownloadedOnly {
                return videos.filter { downloadedVideoIDs.contains($0.videoId) }
            }
            switch watchFilter {
            case .all:
                return videos
            case .unwatched:
                return videos.filter { !$0.isWatched }
            case .watched:
                return videos.filter { $0.isWatched }
            }
        }
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
        case videosLoaded(PaginatedResponse<VideoResponse>)
        case videosFailed(Error)
        case contextDeleteCompleted(String)
        case contextDeleteFailed(Error)
        case markWatchedCompleted(String)
        case markWatchedFailed
        case videoRefreshed(VideoResponse)
        case searchResultsLoaded([VideoResponse])
        case searchFailed
        case addVideo(PresentationAction<AddVideoReducer.Action>)
        case pipRestoreVideo(VideoResponse)

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case videoTapped(VideoResponse)
            case downloadToDeviceTapped(VideoResponse)
            case deleteFromServerTapped(VideoResponse)
            case watchFilterChanged(WatchFilter)
            case downloadedFilterTapped
            case addToPlaylistTapped(VideoResponse)
            case markAsWatchedTapped(VideoResponse)
            case playNextTapped(VideoResponse)
            case addVideoTapped
            case pipRestoreNotificationReceived
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
            case .selectedVideoDetail(.serverDeleteCompleted):
                state.selectedVideo = nil
                return .send(.view(.pullToRefreshTriggered))
            case .selectedVideoDetail:
                return .none
            case .presentedVideo(.presented(.serverDeleteCompleted)):
                state.presentedVideo = nil
                return .send(.view(.pullToRefreshTriggered))
            case .presentedVideo:
                return .none
            case .path(.element(_, action: .videoDetail(.serverDeleteCompleted))):
                _ = state.path.popLast()
                return .send(.view(.pullToRefreshTriggered))
            case .path:
                return .none
            case .playlistPicker:
                return .none
            case .addVideo(.presented(.addSucceeded)):
                state.addVideo = nil
                return .send(.view(.pullToRefreshTriggered))
            case .addVideo:
                return .none
            case .alert:
                return .none
            case .videoDetail(.presented(.serverDeleteCompleted)):
                state.videoDetail = nil
                return .send(.view(.pullToRefreshTriggered))
            case .videoDetail:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
