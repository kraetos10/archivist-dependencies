import ArchivistNetworking
import ComposableArchitecture
import Foundation

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
        var showPlayNext: Bool = true
        var isDownloaded = false
        var isDownloading = false
        var downloadProgress: Double = 0
        var downloadError: String?
        var isDeletingFromServer = false
        var isDescriptionExpanded = false
        var watchedOverride: Bool?
        @Presents var playlistPicker: PlaylistPickerReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        var youtubeURL: URL { video.youtubeURL }
        var isWatched: Bool { watchedOverride ?? video.isWatched }

        public init(serverConfig: ServerConfig, video: VideoResponse, nextVideos: [VideoResponse] = [], showPlayNext: Bool = true, isPlaying: Bool = false) {
            self.serverConfig = serverConfig
            self.video = video
            self.nextVideos = nextVideos
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
            watchedOverride = nil
            playlistPicker = nil
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction {
        case view(View)
        case delegate(Delegate)

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
        case pipRestoreRequested(VideoResponse)
        case serverDeleteResult(Result<Void, Error>)
        case loadNextVideo
        case watchedToggleResult(Result<Void, Error>)

        public enum Delegate {
            case didRequestMinimize(VideoResponse, [VideoResponse], ServerConfig, Bool)
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
            case removeFromPlayNextTapped(Int)
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.videoService) var videoService
    @Dependency(\.localVideoStorage) var localVideoStorage
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.playNextDatabase) var playNextDatabase

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .delegate:
                return .none
            case .playlistPicker:
                return .none
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
