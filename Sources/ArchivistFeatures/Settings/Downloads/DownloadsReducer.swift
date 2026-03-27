import ArchivistNetworking
import ComposableArchitecture
import Foundation

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
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<DownloadResponse> = []
        var isSearching = false
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
                return title.localizedCaseInsensitiveContains(searchQuery)
                    || channel.localizedCaseInsensitiveContains(searchQuery)
            }
            var merged = searchResults
            for download in localMatches {
                merged.updateOrAppend(download)
            }
            return merged
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case confirmDownload(String)
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case alert(PresentationAction<AlertAction>)
        case downloadsLoaded(PaginatedResponse<DownloadResponse>)
        case downloadsFailed(Error)
        case searchResultsLoaded(PaginatedResponse<DownloadResponse>)
        case searchFailed
        case downloadDeleted(String)
        case downloadDeleteFailed(Error)
        case downloadDetail(PresentationAction<DownloadDetailReducer.Action>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case downloadTapped(DownloadResponse)
            case deleteTapped(DownloadResponse)
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
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
            case .downloadDetail(.presented(.view(.dismissTapped))):
                state.downloadDetail = nil
                return .none
            case .downloadDetail(.presented(.downloadStarted)):
                state.downloadDetail = nil
                return .send(.view(.pullToRefreshTriggered))
            case .downloadDetail(.presented(.deleteSucceeded)):
                let videoId = state.downloadDetail?.download.youtubeId
                state.downloadDetail = nil
                if let videoId {
                    state.downloads.remove(id: videoId)
                }
                return .none
            case .downloadDetail:
                return .none
            case .alert(.presented(.confirmDownload(let videoId))):
                let config = state.serverConfig
                return .run { [downloadService] _ in
                    try await downloadService.updateDownload(config: config, id: videoId, status: "priority")
                }
            case .alert:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$downloadDetail, action: \.downloadDetail) {
            DownloadDetailReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
