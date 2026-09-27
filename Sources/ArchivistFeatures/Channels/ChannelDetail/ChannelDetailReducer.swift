import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

public enum ChannelVideoFilter: Sendable, Equatable {
    case all
    case unwatched

    /// tvOS has no filter control, so it shows everything; iOS opens on
    /// the unwatched videos.
    static var platformDefault: Self {
        #if os(tvOS)
        return .all
        #else
        return .unwatched
        #endif
    }
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
        var videoFilter: ChannelVideoFilter = .platformDefault
        var videoSortOrder: VideoSortOrder = .published
        @FetchAll(PlayNextItem.all.order(by: \.id))
        var playNextItems
        @FetchAll(
            DeviceDownload
                .where { $0.status.eq(DeviceDownloadStatus.completed) }
        )
        var completedDownloads

        /// The videos the carousel draws: queued-for-play-next ones are
        /// left out, and the watched filter applies.
        var filteredVideos: IdentifiedArrayOf<VideoResponse> {
            let queuedIDs = Set(playNextItems.map(\.videoId))
            let base = videos.filter { !queuedIDs.contains($0.videoId) }
            switch videoFilter {
            case .all:
                return base
            case .unwatched:
                return base.filter { $0.isUnwatched }
            }
        }

        var downloadedVideoIDs: Set<String> {
            Set(completedDownloads.map(\.id))
        }

        var showsPendingDownloads: Bool {
            !pendingDownloads.isEmpty || isLoadingDownloads
        }

        @Presents var alert: AlertState<AlertAction>?

        @Presents var downloadDetail: DownloadDetailReducer.State?

        @Presents var playlistPicker: PlaylistPickerReducer.State?

        var channelThumbURL: URL? {
            guard let path = channel.channelThumbUrl else { return nil }
            return serverConfig.fullURL(for: path)
        }

        var channelBannerURL: URL? {
            guard let path = channel.channelBannerUrl else { return nil }
            return serverConfig.fullURL(for: path)
        }

        /// The description split into non-empty lines, one focus stop each
        /// on the tvOS full-description screen.
        var descriptionBlocks: [String] {
            (channel.channelDescription ?? "").descriptionBlocks()
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case confirmUnsubscribe
        case confirmDownload(String)
        case confirmClearFiltered
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case alert(PresentationAction<AlertAction>)
        case videosResult(Result<PaginatedResponse<VideoResponse>, Error>)
        case downloadsResult(Result<PaginatedResponse<DownloadResponse>, Error>)
        case downloadDetail(PresentationAction<DownloadDetailReducer.Action>)
        case playlistPicker(PresentationAction<PlaylistPickerReducer.Action>)
        case unsubscribeResult(Result<Void, Error>)
        case deleteVideoResult(Result<String, Error>)
        case queueDownloadResult(Result<String, Error>)
        case setWatchedResult(
            videoId: String,
            isWatched: Bool,
            Result<Void, Error>
        )
        /// Sent by the parent when a server download finishes, so the
        /// pending list drops what just completed.
        case refreshPendingDownloads

        public enum Delegate: Equatable, Sendable {
            case videoSelected(VideoResponse, nextVideos: [VideoResponse])
            case didUnsubscribe(String)
        }

        @CasePathable
        public enum View {
            case viewDidAppear
            case pullToRefreshTriggered
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
            case playNextTapped(VideoResponse)
            case addToPlaylistTapped(VideoResponse)
            case downloadSortToggled
            case videoSortOrderChanged(VideoSortOrder)
            case clearFilteredTapped
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        case videos
        case downloads
    }

    @Dependency(\.videoService) var videoService
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.channelService) var channelService
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.localVideoStorage) var localVideoStorage
    @Dependency(\.playNextDatabase) var playNextDatabase
    @Dependency(\.date.now) var now

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .binding, .delegate:
                return .none
            case .downloadDetail(.presented(.delegate(.didQueueDownload(let youtubeId)))),
                 .downloadDetail(.presented(.delegate(.didDelete(let youtubeId)))):
                return handleDownloadDetailFinished(youtubeId, state: &state)
            case .downloadDetail, .playlistPicker:
                return .none
            case .alert(.presented(.confirmUnsubscribe)):
                return handleUnsubscribeConfirmed(state: &state)
            case .alert(.presented(.confirmClearFiltered)):
                return handleConfirmClearFiltered(state: &state)
            case .alert(.presented(.confirmDownload(let videoId))):
                return handleConfirmDownload(videoId, state: &state)
            case .alert:
                return .none
            case .videosResult, .downloadsResult, .unsubscribeResult,
                 .deleteVideoResult, .queueDownloadResult, .setWatchedResult,
                 .refreshPendingDownloads:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$downloadDetail, action: \.downloadDetail) {
            DownloadDetailReducer()
        }
        .ifLet(\.$playlistPicker, action: \.playlistPicker) {
            PlaylistPickerReducer()
        }
    }
}
