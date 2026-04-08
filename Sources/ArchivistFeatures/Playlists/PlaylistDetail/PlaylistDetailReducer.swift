import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct PlaylistDetailReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var playlist: PlaylistResponse
        var isLoadingEntries = false
        var hasLoadedEntries = false
        var isEditing = false
        var entryThumbnails: [String: String] = [:]
        var availableVideoIDs: Set<String> = []
        @Presents var alert: AlertState<AlertAction>?
        @Presents var videoPicker: VideoPickerReducer.State?

        var playlistThumbURL: URL? {
            playlist.thumbURL(config: serverConfig)
        }

        var entries: [PlaylistEntry] {
            playlist.playlistEntries ?? []
        }

        var entryThumbURLs: [String: URL] {
            var result: [String: URL] = [:]
            for entry in entries {
                guard let videoId = entry.youtubeId else { continue }
                if let url = entry.thumbURL(config: serverConfig) {
                    result[videoId] = url
                } else if let path = entryThumbnails[videoId],
                          let url = serverConfig.fullURL(for: path) {
                    result[videoId] = url
                }
            }
            return result
        }

        var isCustomPlaylist: Bool {
            playlist.playlistType == .custom
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case confirmUnsubscribe
        case confirmServerDownload(String)
    }

    public enum Action: ViewAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case playlistResult(Result<PlaylistResponse, Error>)
        case videoResult(Result<(VideoResponse, nextVideos: [VideoResponse]), Error>)
        case unsubscribeResult(Result<Void, Error>)
        case removeEntryResult(Result<String, Error>)
        case moveEntryResult(Result<Void, Error>)
        case thumbnailsLoaded([String: String], availableIDs: Set<String>)
        case videoPicker(PresentationAction<VideoPickerReducer.Action>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case entryTapped(PlaylistEntry)
            case dismissTapped
            case unsubscribeTapped
            case removeEntryTapped(PlaylistEntry)
            case moveEntry(IndexSet, Int)
            case editTapped
            case addVideoTapped
            case downloadToDeviceTapped(PlaylistEntry)
            case queueServerDownloadTapped(PlaylistEntry)
            case markAsWatchedTapped(PlaylistEntry)
        }

        public enum Delegate: Equatable, Sendable {
            case showVideo(VideoResponse, nextVideos: [VideoResponse])
        }
    }

    @Dependency(\.playlistService) var playlistService
    @Dependency(\.videoService) var videoService
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .alert(.presented(.confirmUnsubscribe)):
                return handleUnsubscribeConfirmed(state: &state)
            case .alert(.presented(.confirmServerDownload(let videoId))):
                let config = state.serverConfig
                let items = [AddDownloadItem(youtubeId: videoId, status: "pending")]
                return .run { [downloadService] _ in
                    try? await downloadService.addDownloads(
                        config: config,
                        items: items,
                        autostart: true,
                        flat: false,
                        force: false
                    )
                }
            case .alert:
                return .none
            case .delegate:
                return .none
            case .videoPicker(.presented(.addResult(.success))):
                state.videoPicker = nil
                state.hasLoadedEntries = false
                return .send(.view(.viewDidAppear))
            case .videoPicker:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$videoPicker, action: \.videoPicker) {
            VideoPickerReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
