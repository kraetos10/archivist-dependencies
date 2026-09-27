import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct VideoPickerReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var playlistId: String
        var videos: IdentifiedArrayOf<VideoResponse> = []
        var pendingDownloads: IdentifiedArrayOf<DownloadResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var isLoadingDownloads = false
        var hasLoaded = false
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<VideoResponse> = []
        var isSearching = false
        /// In the order they were picked, which is the order they're added
        /// to the playlist.
        var selectedVideoIds: [String] = []
        var isAdding = false
        /// The rows on screen. Stored, not computed: building it merges,
        /// filters and sorts every item, so it's rebuilt only when its
        /// inputs change (`updateDisplayedItems()`), never per render.
        var displayedItems: [VideoListItem] = []
        @Presents var alert: AlertState<AlertAction>?

        var isSearchActive: Bool { !searchQuery.isEmpty }

        var lastVideoId: String? {
            videos.last?.videoId
        }

        func isSelected(_ item: VideoListItem) -> Bool {
            selectedVideoIds.contains(item.id)
        }

        mutating func updateDisplayedItems() {
            if isSearchActive {
                let localMatches = videos.filter {
                    $0.title.localizedStandardContains(searchQuery)
                }
                var mergedVideos = searchResults
                for video in localMatches {
                    mergedVideos.updateOrAppend(video)
                }
                let videoItems: [VideoListItem] = mergedVideos.map { .video($0) }
                let videoIds = Set(mergedVideos.map(\.videoId))
                let downloadItems: [VideoListItem] = pendingDownloads
                    .filter { !videoIds.contains($0.youtubeId) }
                    .filter {
                        ($0.title ?? "").localizedStandardContains(searchQuery)
                        || ($0.channelName ?? "").localizedStandardContains(searchQuery)
                    }
                    .map { .download($0) }
                displayedItems = videoItems + downloadItems
                return
            }

            let videoIds = Set(videos.map(\.videoId))
            let videoItems: [VideoListItem] = videos.map { .video($0) }
            let downloadItems: [VideoListItem] = pendingDownloads
                .filter { !videoIds.contains($0.youtubeId) }
                .map { .download($0) }
            displayedItems = (videoItems + downloadItems).sorted { lhs, rhs in
                guard let lhsDate = lhs.publishedDate, let rhsDate = rhs.publishedDate else {
                    return lhs.publishedDate != nil
                }
                return lhsDate > rhsDate
            }
        }
    }

    public enum AlertAction: Equatable, Sendable {}

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case videosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        case downloadsResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case searchResult(Result<[VideoResponse], Error>)
        /// The ids that failed to add; empty means every one went in.
        case addFinished(failedIds: [String])

        @CasePathable
        public enum View {
            case viewDidAppear
            case videoToggled(VideoListItem)
            case addTapped
            case lastItemAppeared
        }

        public enum Delegate: Equatable, Sendable {
            case didAddVideos
        }
    }

    @Dependency(\.videoService) var videoService
    @Dependency(\.searchService) var searchService
    @Dependency(\.playlistService) var playlistService
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss

    nonisolated enum CancelID: Hashable, Sendable {
        case search
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchQuery):
                return handleSearchQueryChanged(state: &state)
            case .binding, .alert, .delegate:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .videosResult, .downloadsResult, .searchResult, .addFinished:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
