#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct DeviceDownloadsReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var downloadsSize: Int64 = 0
        var availableStorage: Int64 = 0
        var totalStorage: Int64 = 0
    }

    public enum Action: ViewAction {
        case view(View)
        case delegate(Delegate)
        case storageInfoLoaded(downloadsSize: Int64, available: Int64, total: Int64)

        @CasePathable
        public enum View {
            case viewDidAppear
            case deleteTapped(String)
            case downloadTapped(DeviceDownload)
        }

        public enum Delegate: Equatable, Sendable {
            case playVideo(VideoResponse)
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
            case .delegate:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
#endif
