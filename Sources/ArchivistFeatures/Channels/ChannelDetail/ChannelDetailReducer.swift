import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

/// Which of the channel's videos the list shows. Filtered by the server, so
/// a channel whose newest videos are all watched still finds its unwatched
/// ones further back.
public enum ChannelVideoFilter: CaseIterable, Sendable, Equatable {
    case unwatched
    case inProgress
    case watched
    case all

    /// The `watch` value for `/api/video/`.
    var apiValue: String? {
        switch self {
        case .unwatched: "unwatched"
        case .inProgress: "continue"
        case .watched: "watched"
        case .all: nil
        }
    }

    /// Re-checked locally so a video marked watched (or back) here leaves a
    /// list it no longer belongs in without a refetch.
    func includes(_ video: VideoResponse) -> Bool {
        switch self {
        case .unwatched: !video.isWatched
        case .inProgress: video.isPartiallyWatched
        case .watched: video.isWatched
        case .all: true
        }
    }

    var label: String {
        switch self {
        case .unwatched: String.localised("generic.unwatched", table: .generic)
        case .inProgress: String.localised("video.inProgress", table: .videos)
        case .watched: String.localised("video.watched", table: .videos)
        case .all: String.localised("generic.all", table: .generic)
        }
    }

    var emptyMessage: String {
        switch self {
        case .unwatched: String.localised("video.empty.noUnwatched", table: .videos)
        case .inProgress: String.localised("video.empty.noContinueWatching", table: .videos)
        case .watched: String.localised("video.empty.noWatched", table: .videos)
        case .all: String.localised("video.empty.noVideos", table: .videos)
        }
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
        /// The pending-downloads list stays folded into one row until asked
        /// for: below a list that pages forever it could never be reached.
        var isPendingDownloadsExpanded = false
        var videoFilter: ChannelVideoFilter = .unwatched
        /// iOS multi-select. While on, tapping a card selects it.
        var isSelecting = false
        var selectedVideoIDs: Set<String> = []
        var videoSortOrder: VideoSortOrder = .published
        @FetchAll(PlayNextItem.all.order(by: \.id))
        var playNextItems
        @FetchAll(
            DeviceDownload
                .where { $0.status.eq(DeviceDownloadStatus.completed) }
        )
        var completedDownloads

        /// The videos the list draws: queued-for-play-next ones are left
        /// out, and the watched filter is re-applied to local changes.
        var filteredVideos: IdentifiedArrayOf<VideoResponse> {
            let queuedIDs = Set(playNextItems.map(\.videoId))
            let filter = videoFilter
            return videos.filter { !queuedIDs.contains($0.videoId) && filter.includes($0) }
        }

        /// The selected videos still in the list, in list order.
        var selectedVideos: [VideoResponse] {
            filteredVideos.filter { selectedVideoIDs.contains($0.videoId) }
        }

        var selectionTitle: String {
            String.localised("video.selectedCount \(selectedVideos.count)", table: .videos)
        }

        var areAllVideosSelected: Bool {
            let visible = filteredVideos
            return !visible.isEmpty && visible.allSatisfy { selectedVideoIDs.contains($0.videoId) }
        }

        /// Marking unwatched only makes sense once everything picked is
        /// watched; anything else in the mix gets marked watched.
        var selectionMarksWatched: Bool {
            !selectedVideos.allSatisfy(\.isWatched)
        }

        var pendingDownloadsTitle: String {
            String.localised("video.pendingDownloadsCount \(pendingDownloads.count)", table: .videos)
        }

        var downloadedVideoIDs: Set<String> {
            Set(completedDownloads.map(\.id))
        }

        var showsPendingDownloads: Bool {
            !pendingDownloads.isEmpty
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
        case confirmDeleteSelected
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
            case pendingDownloadsToggled
            case selectTapped
            case doneSelectingTapped
            case selectAllTapped
            case markSelectedWatchedTapped
            case downloadSelectedToDeviceTapped
            case deleteSelectedTapped
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
            case .alert(.presented(.confirmDeleteSelected)):
                return handleConfirmDeleteSelected(state: &state)
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
