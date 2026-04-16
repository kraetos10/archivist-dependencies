import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum ChannelVideoFilter: Sendable, Equatable {
    case all
    case unwatched
}

@Reducer
public struct ChannelDetailReducer: Sendable {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var channel: ChannelResponse
        var videos: IdentifiedArrayOf<VideoResponse> = []
        var currentPage: Int = 1
        var lastPage: Int = 1
        var isLoadingVideos = false
        var isLoadingMoreVideos = false
        var hasLoadedVideos = false
        var pendingDownloads: IdentifiedArrayOf<DownloadResponse> = []
        var isLoadingDownloads = false
        var hasLoadedDownloads = false
        var showNewestDownloadsFirst = true
        var isDescriptionExpanded = false
        var videoFilter: ChannelVideoFilter = .unwatched
        var videoSortOrder: VideoSortOrder = .published

        var filteredVideos: IdentifiedArrayOf<VideoResponse> {
            switch videoFilter {
            case .all:
                return videos
            case .unwatched:
                return videos.filter { !$0.isWatched }
            }
        }

        @Presents var alert: AlertState<AlertAction>?

        @Presents var downloadDetail: DownloadDetailReducer.State?

        var channelThumbURL: URL? {
            guard let path = channel.channelThumbUrl else { return nil }
            return serverConfig.fullURL(for: path)
        }

        var channelBannerURL: URL? {
            guard let path = channel.channelBannerUrl else { return nil }
            return serverConfig.fullURL(for: path)
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case confirmUnsubscribe
        case confirmDownload(String)
    }

    public enum Action: ViewAction {
        case view(View)
        case delegate(Delegate)
        case alert(PresentationAction<AlertAction>)
        case videosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        case downloadsResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case downloadDetail(PresentationAction<DownloadDetailReducer.Action>)
        case unsubscribeResult(Result<Void, Error>)
        case deleteVideoResult(Result<String, Error>)

        public enum Delegate: Equatable, Sendable {
            case videoSelected(VideoResponse, nextVideos: [VideoResponse])
        }

        @CasePathable
        public enum View {
            case viewDidAppear
            case lastVideoAppeared
            case videoCardTapped(VideoResponse)
            case downloadCardTapped(DownloadResponse)
            case unsubscribeTapped
            case descriptionToggleTapped
            case videoFilterChanged(ChannelVideoFilter)
            case downloadToDeviceTapped(VideoResponse)
            case deleteFromDeviceTapped(VideoResponse)
            case markAsWatchedTapped(VideoResponse)
            case deleteFromServerTapped(VideoResponse)
            case downloadSortToggled
            case videoSortOrderChanged(VideoSortOrder)
        }
    }

    @Dependency(\.videoService) var videoService
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.channelService) var channelService
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.localVideoStorage) var localVideoStorage

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .delegate:
                return .none
            case .downloadDetail(.presented(.view(.dismissTapped))):
                state.downloadDetail = nil
                return .none
            case .downloadDetail(.presented(.downloadResult(.success))):
                state.downloadDetail = nil
                return .none
            case .downloadDetail(.presented(.deleteResult(.success))):
                let youtubeId = state.downloadDetail?.download.youtubeId
                state.downloadDetail = nil
                if let youtubeId {
                    state.pendingDownloads.remove(id: youtubeId)
                }
                return .none
            case .downloadDetail:
                return .none
            case .alert(.presented(.confirmUnsubscribe)):
                return handleUnsubscribeConfirmed(state: &state)
            case .alert(.presented(.confirmDownload(let videoId))):
                let config = state.serverConfig
                return .run { _ in
                    try await downloadService.updateDownload(config: config, id: videoId, status: "priority")
                }
            case .alert:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$downloadDetail, action: \.downloadDetail) {
            DownloadDetailReducer()
        }
    }
}
