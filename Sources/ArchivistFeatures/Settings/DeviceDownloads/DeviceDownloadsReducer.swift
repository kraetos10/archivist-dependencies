#if !os(tvOS)
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
        var downloadsSize: Int64 = 0
        var availableStorage: Int64 = 0
        var totalStorage: Int64 = 0
        @FetchAll(
            DeviceDownload
                .where { $0.status.eq(DeviceDownloadStatus.completed) }
                .order { $0.createdAt.desc() }
        )
        var completedDownloads
        @Presents var playlistPicker: PlaylistPickerReducer.State?
        @Presents var videoDetail: VideoDetailReducer.State?
        @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled = true

        public init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
        }
    }

    public enum Action: ViewAction {
        case view(View)
        case playlistPicker(PresentationAction<PlaylistPickerReducer.Action>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)
        case storageInfoLoaded(downloadsSize: Int64, available: Int64, total: Int64)

        @CasePathable
        public enum View {
            case viewDidAppear
            case viewDidDisappear
            case deleteTapped(String)
            case downloadTapped(DeviceDownload)
            case addToPlaylistTapped(DeviceDownload)
        }
    }

    @Dependency(\.localVideoStorage) var localVideoStorage
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
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
            case .videoDetail, .playlistPicker:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$playlistPicker, action: \.playlistPicker) {
            PlaylistPickerReducer()
        }
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
    }
}
#endif
