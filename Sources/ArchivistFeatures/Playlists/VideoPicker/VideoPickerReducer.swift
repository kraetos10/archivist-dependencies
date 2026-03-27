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
        var selectedVideoIds: Set<String> = []
        var isAdding = false

        var isSearchActive: Bool { !searchQuery.isEmpty }

        var displayedItems: [VideoListItem] {
            if isSearchActive {
                let localMatches = videos.filter {
                    $0.title.localizedCaseInsensitiveContains(searchQuery)
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
                        ($0.title ?? "").localizedCaseInsensitiveContains(searchQuery)
                        || ($0.channelName ?? "").localizedCaseInsensitiveContains(searchQuery)
                    }
                    .map { .download($0) }
                return videoItems + downloadItems
            }

            let videoIds = Set(videos.map(\.videoId))
            let videoItems: [VideoListItem] = videos.map { .video($0) }
            let downloadItems: [VideoListItem] = pendingDownloads
                .filter { !videoIds.contains($0.youtubeId) }
                .map { .download($0) }
            let allItems = videoItems + downloadItems
            return allItems.sorted { lhs, rhs in
                guard let lhsDate = lhs.publishedDate, let rhsDate = rhs.publishedDate else {
                    return lhs.publishedDate != nil
                }
                return lhsDate > rhsDate
            }
        }

        var lastVideoId: String? {
            videos.last?.videoId
        }
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case videosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        case downloadsResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case searchResult(Result<[VideoResponse], Error>)
        case addResult(Result<Void, Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case videoToggled(VideoListItem)
            case addTapped
            case lastItemAppeared
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
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
