import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum DownloadSortOrder: String, Sendable, Equatable {
    case newestFirst
    case oldestFirst
}

@Reducer
public struct DownloadsReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var downloads: IdentifiedArrayOf<DownloadResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoading = false
        var isLoadingMore = false
        var hasLoaded = false
        @Shared(.downloadsSortOrder) var sortOrder
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<DownloadResponse> = []
        var isSearching = false
        var scrollPositionID: String?
        /// tvOS: the focused card, bound to the screen's focus state so a
        /// removal can move focus to the neighbouring card.
        var focusedDownloadID: String?
        @Presents var downloadDetail: DownloadDetailReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        var isSearchActive: Bool {
            !searchQuery.isEmpty
        }

        var filteredDownloads: IdentifiedArrayOf<DownloadResponse> {
            guard isSearchActive else { return downloads }
            let localMatches = downloads.filter { download in
                let title = download.title ?? ""
                let channel = download.channelName ?? ""
                return title.localizedStandardContains(searchQuery)
                    || channel.localizedStandardContains(searchQuery)
            }
            var merged = searchResults
            for download in localMatches {
                merged.updateOrAppend(download)
            }
            return merged
        }

        /// Redacted placeholder cards while the first page loads.
        var showsPlaceholders: Bool {
            isLoading && downloads.isEmpty
        }

        /// Loaded, nothing queued, not searching.
        var showsEmptyQueue: Bool {
            hasLoaded && !isSearchActive && filteredDownloads.isEmpty
        }

        /// Loaded, searching, nothing matches.
        var showsNoSearchResults: Bool {
            hasLoaded && isSearchActive && filteredDownloads.isEmpty
        }

        public init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case confirmDownload(String)
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case alert(PresentationAction<AlertAction>)
        case bumpResult(Result<Void, Error>)
        case downloadsResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case searchResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case deleteResult(Result<String, Error>)
        case downloadDetail(PresentationAction<DownloadDetailReducer.Action>)
        /// Entry point for parents: reload the queue from page one.
        case refresh

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case itemAppeared(String)
            case downloadTapped(DownloadResponse)
            case deleteTapped(DownloadResponse)
            case sortOrderChanged(DownloadSortOrder)
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        /// Page loads. A refresh or sort change supersedes whatever page
        /// was in flight, so its stale result can't land on the new list.
        case fetch
        case search
    }

    @Dependency(\.downloadService) var downloadService
    @Dependency(\.continuousClock) var clock

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
            case .refresh:
                return handleRefresh(state: &state)
            case .downloadDetail(.presented(.delegate(.didQueueDownload(let videoId)))),
                 .downloadDetail(.presented(.delegate(.didDelete(let videoId)))):
                return handleDetailFinished(videoId, state: &state)
            case .alert(.presented(.confirmDownload(let videoId))):
                return handleConfirmDownload(videoId, state: &state)
            case .bumpResult(let result):
                return handleBumpResult(result, state: &state)
            case .downloadsResult(let result):
                return handleDownloadsResult(result, state: &state)
            case .searchResult(let result):
                return handleSearchResult(result, state: &state)
            case .deleteResult(let result):
                return handleDeleteResult(result, state: &state)
            case .alert, .downloadDetail:
                return .none
            }
        }
        .ifLet(\.$downloadDetail, action: \.downloadDetail) {
            DownloadDetailReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
