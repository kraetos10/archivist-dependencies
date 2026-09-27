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
        var entryThumbnails: [String: String] = [:]
        var availableVideoIDs: Set<String> = []
        /// tvOS: the full description is presented over the screen.
        var isShowingFullDescription = false
        @Shared(.loopPlaylist) var loopPlaylistEnabled
        @Presents var alert: AlertState<AlertAction>?
        @Presents var videoPicker: VideoPickerReducer.State?

        var playlistThumbURL: URL? {
            playlist.thumbURL(config: serverConfig)
        }

        var entries: [PlaylistEntry] {
            playlist.playlistEntries ?? []
        }

        /// Thumbnail per entry id. Builds a dictionary over every entry, so
        /// read it once per render, not once per row.
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

        /// The description to show, or `nil`. The API returns the string
        /// "false" for playlists with no description rather than omitting
        /// the field, so that's filtered out here.
        var displayDescription: String? {
            guard let description = playlist.playlistDescription,
                  !description.isEmpty,
                  description.lowercased() != "false"
            else { return nil }
            return description
        }

        /// The description split into non-empty lines, one focus stop each
        /// on the tvOS full-description screen.
        var descriptionBlocks: [String] {
            (displayDescription ?? "").descriptionBlocks()
        }

        func isEntryAvailable(_ entry: PlaylistEntry) -> Bool {
            entry.youtubeId.map { availableVideoIDs.contains($0) } ?? false
        }

        var isCustomPlaylist: Bool {
            playlist.playlistType == .custom
        }

        /// Ordered entry IDs handed to the player so it can wrap back to the
        /// top of the playlist. Empty unless looping is switched on.
        var loopVideoIds: [String] {
            loopPlaylistEnabled ? entries.compactMap(\.youtubeId) : []
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case confirmUnsubscribe
        case confirmServerDownload(String)
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case playlistResult(Result<PlaylistResponse, Error>)
        case videoResult(Result<(VideoResponse, nextVideos: [VideoResponse]), Error>)
        case unsubscribeResult(Result<Void, Error>)
        case removeEntryResult(Result<String, Error>)
        case setWatchedResult(Result<String, Error>)
        case serverDownloadResult(Result<String, Error>)
        case thumbnailsLoaded([String: String], availableIDs: Set<String>)
        case videoPicker(PresentationAction<VideoPickerReducer.Action>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case entryTapped(PlaylistEntry)
            case unsubscribeTapped
            case removeEntryTapped(PlaylistEntry)
            case addVideoTapped
            case downloadToDeviceTapped(PlaylistEntry)
            case markAsWatchedTapped(PlaylistEntry)
            case loopToggled
            case descriptionTapped
        }

        public enum Delegate: Equatable, Sendable {
            case showVideo(
                VideoResponse,
                nextVideos: [VideoResponse],
                loopVideoIds: [String]
            )
            case didUnsubscribe(String)
        }
    }

    nonisolated enum CancelID: Hashable, Sendable {
        case load
        case thumbnails
        case openEntry
    }

    /// How many entry lookups run at once when filling in thumbnails.
    static let thumbnailFetchConcurrency = 6

    @Dependency(\.playlistService) var playlistService
    @Dependency(\.videoService) var videoService
    @Dependency(\.downloadService) var downloadService
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.date.now) var now

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .binding, .delegate:
                return .none
            case .alert(.presented(.confirmUnsubscribe)):
                return handleUnsubscribeConfirmed(state: &state)
            case .alert(.presented(.confirmServerDownload(let videoId))):
                return handleServerDownloadConfirmed(videoId, state: &state)
            case .alert:
                return .none
            case .videoPicker(.presented(.delegate(.didAddVideos))):
                // The picker dismisses itself; reload to show what it added.
                return reloadPlaylist(state: &state)
            case .videoPicker:
                return .none
            case .playlistResult, .videoResult, .unsubscribeResult,
                 .removeEntryResult, .setWatchedResult, .serverDownloadResult,
                 .thumbnailsLoaded:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$videoPicker, action: \.videoPicker) {
            VideoPickerReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
