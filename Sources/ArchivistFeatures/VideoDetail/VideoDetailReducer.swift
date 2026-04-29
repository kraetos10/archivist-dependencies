import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

@Reducer
public struct VideoDetailReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable, Identifiable {
        public var id: String { video.videoId }
        var serverConfig: ServerConfig
        var video: VideoResponse
        var isPlaying: Bool = false
        var comments: [VideoComment] = []
        var isLoadingComments = false
        var similarVideos: [VideoResponse] = []
        var isLoadingSimilar = false
        var nextVideos: [VideoResponse] = []
        /// Stack of videos we've auto-advanced past in this detail session —
        /// powers the "previous" transport button.
        var previousVideos: [VideoResponse] = []
        var shouldAutoPlayNextVideo: Bool = true
        var showPlayNext: Bool = true
        var isDownloaded = false
        var isDownloading = false
        var downloadProgress: Double = 0
        var downloadError: String?
        var isCached = false
        var isDeletingFromServer = false
        var isDescriptionExpanded = false
        var showAllComments = false
        var currentCommentIndex = 0
        var watchedOverride: Bool?
        var localWatchProgress: Double?
        @FetchAll(PlayNextItem.all.order(by: \.id))
        var playNextItems
        @Presents var playlistPicker: PlaylistPickerReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        var youtubeURL: URL? { video.youtubeURL }
        var isWatched: Bool { watchedOverride ?? video.isWatched }
        var effectiveWatchProgress: Double { localWatchProgress ?? video.watchProgress }
        var channelThumbURL: URL? {
            guard let path = video.channel.channelThumbUrl else { return nil }
            return serverConfig.fullURL(for: path)
        }

        public init(
            serverConfig: ServerConfig,
            video: VideoResponse,
            nextVideos: [VideoResponse] = [],
            shouldAutoPlayNextVideo: Bool = true,
            showPlayNext: Bool = true,
            isPlaying: Bool = false
        ) {
            self.serverConfig = serverConfig
            self.video = video
            self.nextVideos = nextVideos
            self.shouldAutoPlayNextVideo = shouldAutoPlayNextVideo
            self.showPlayNext = showPlayNext
            self.isPlaying = isPlaying
        }

        mutating func resetForNewVideo(_ video: VideoResponse) {
            self.video = video
            isPlaying = false
            comments = []
            isLoadingComments = false
            similarVideos = []
            isLoadingSimilar = false
            isDownloaded = false
            isDownloading = false
            downloadProgress = 0
            downloadError = nil
            isDeletingFromServer = false
            isDescriptionExpanded = false
            showAllComments = false
            currentCommentIndex = 0
            watchedOverride = nil
            playlistPicker = nil
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
        case confirmDeleteFromServer
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case delegate(Delegate)
        case binding(BindingAction<State>)

        case playlistPicker(PresentationAction<PlaylistPickerReducer.Action>)
        case alert(PresentationAction<AlertAction>)
        case videoRefreshed(VideoResponse)
        case commentsResult(Result<[VideoComment], Error>)
        case similarResult(Result<[VideoResponse], Error>)
        case downloadResumed(Double)
        case downloadProgressUpdated(Double)
        case downloadCompleted
        case downloadFailed(String)
        case autoPlayVideo(VideoResponse)
        case cacheStatusChanged(Bool)
        case pipRestoreRequested(VideoResponse)
        case adoptInflightPlayback
        case serverDeleteResult(Result<Void, Error>)
        case loadNextVideo
        case watchedToggleResult(Result<Void, Error>)

        public enum Delegate {
            case didRequestMinimize
            case didDismiss(String)
        }

        @CasePathable
        public enum View {
            case viewDidAppear
            case playTapped
            case stopPlayback
            case dismissTapped
            case downloadTapped
            case deleteDownloadTapped
            case deleteFromServerTapped
            case similarVideoTapped(VideoResponse)
            case nextUpVideoTapped(VideoResponse)
            case videoPlaybackDidEnd
            case toggleDescription
            case toggleWatchedTapped
            case addToPlaylistTapped
            case addToPlayNextTapped
            case addUpNextToPlayNextTapped(VideoResponse)
            case removeFromPlayNextTapped(Int)
            case playNextItemTapped(PlayNextItem)
            case nextVideoRequested
            case previousVideoRequested
            case videoChanged
        }
    }

    enum CancelID { case playback }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.videoService) var videoService
    @Dependency(\.localVideoStorage) var localVideoStorage
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.playNextDatabase) var playNextDatabase

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .delegate:
                return .none
            case .playlistPicker:
                return .none
            case .alert(.presented(.confirmDeleteFromServer)):
                return handleConfirmedDeleteFromServer(state: &state)
            case .alert:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$playlistPicker, action: \.playlistPicker) {
            PlaylistPickerReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
