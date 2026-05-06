import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum DownloadSortOrder: Sendable, Equatable {
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
        var sortOrder: DownloadSortOrder = .newestFirst
        var searchQuery: String = ""
        var searchResults: IdentifiedArrayOf<DownloadResponse> = []
        var isSearching = false
        var scrollPositionID: String?
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
        case downloadsResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case searchResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case deleteResult(Result<String, Error>)
        case downloadDetail(PresentationAction<DownloadDetailReducer.Action>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
            case lastItemAppeared
            case downloadTapped(DownloadResponse)
            case deleteTapped(DownloadResponse)
            case sortOrderChanged(DownloadSortOrder)
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
            case .downloadDetail(.presented(.downloadResult(.success))):
                let videoId = state.downloadDetail?.download.youtubeId
                state.downloadDetail = nil
                if let videoId {
                    anchorScrollBeforeRemoval(of: videoId, state: &state)
                    state.downloads.remove(id: videoId)
                }
                return .none
            case .downloadDetail(.presented(.deleteResult(.success))):
                let videoId = state.downloadDetail?.download.youtubeId
                state.downloadDetail = nil
                if let videoId {
                    anchorScrollBeforeRemoval(of: videoId, state: &state)
                    state.downloads.remove(id: videoId)
                }
                return .none
            case .downloadDetail:
                return .none
            case .alert(.presented(.confirmDownload(let videoId))):
                let config = state.serverConfig
                anchorScrollBeforeRemoval(of: videoId, state: &state)
                state.downloads.remove(id: videoId)
                state.searchResults.remove(id: videoId)
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
