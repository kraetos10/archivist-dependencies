#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

@Reducer
public struct DeviceDownloadsReducer {
    public init() {}

    enum CancelID { case storageRefresh }

    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var storage = StorageUsage(downloadsSize: 0, available: 0)
        /// Every download on the device, newest first — the one query the
        /// screen and the auto-advance list both read.
        @FetchAll(DeviceDownload.order { $0.createdAt.desc() })
        var downloads
        @Presents var playlistPicker: PlaylistPickerReducer.State?
        @Presents var videoDetail: VideoDetailReducer.State?
        @Presents var alert: AlertState<AlertAction>?
        @Shared(.autoPlayEnabled) var autoPlayEnabled

        var completedDownloads: [DeviceDownload] {
            downloads.filter(\.isCompleted)
        }

        /// The app's slice of the bar: its downloads against the downloads
        /// plus what's still free. Space other apps use isn't actionable
        /// here, and counting it squeezed our slice to a sliver on a full
        /// device — exactly when the number matters most.
        var downloadsFraction: Double? {
            let scale = storage.downloadsSize + storage.available
            guard scale > 0 else { return nil }
            return Double(storage.downloadsSize) / Double(scale)
        }

        var downloadsSizeText: String {
            String.localised(
                "video.storage.downloads \(storage.downloadsSize.formatted(.byteCount(style: .file)))",
                table: .videos
            )
        }

        var availableStorageText: String {
            String.localised(
                "video.storage.available \(storage.available.formatted(.byteCount(style: .file)))",
                table: .videos
            )
        }

        public init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
    }

    public enum Action: ViewAction {
        case view(View)
        case alert(PresentationAction<AlertAction>)
        case playlistPicker(PresentationAction<PlaylistPickerReducer.Action>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case storageInfoLoaded(StorageUsage)
        case operationFailed(String)

        @CasePathable
        public enum View {
            case viewDidAppear
            case viewDidDisappear
            case deleteTapped(String)
            case downloadTapped(DeviceDownload)
            case addToPlaylistTapped(DeviceDownload)
        }
    }

    @Dependency(\.date.now) var now
    @Dependency(\.continuousClock) var clock
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.deviceStorage) var deviceStorage
    @Dependency(\.localVideoStorage) var localVideoStorage
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.videoService) var videoService

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .videoDetail(.presented(.delegate(.didRequestMinimize))),
                 .videoDetail(.presented(.delegate(.didDismiss))):
                state.videoDetail = nil
                return .none
            case .storageInfoLoaded(let usage):
                state.storage = usage
                return .none
            case .operationFailed(let message):
                return handleOperationFailed(message, state: &state)
            case .alert, .videoDetail, .playlistPicker:
                return .none
            }
        }
        .ifLet(\.$playlistPicker, action: \.playlistPicker) {
            PlaylistPickerReducer()
        }
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
#endif
