import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum StatsSection: Hashable, Sendable, CaseIterable {
    case video, channel, playlist, download, watch, biggestChannels, downloadHistory
}

@Reducer
public struct StatsReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var videoStats: VideoStatsResponse?
        var channelStats: ChannelStatsResponse?
        var playlistStats: PlaylistStatsResponse?
        var downloadStats: DownloadStatsResponse?
        var watchStats: WatchStatsResponse?
        var biggestChannels: [BiggestChannelResponse] = []
        var downloadHistory: [DownloadHistResponse] = []
        var isDownloadHistoryExpanded = false
        var isLoading = false
        var hasLoaded = false
        var loadedSections: Set<StatsSection> = []

        /// Rows shown before "Show All".
        static let collapsedHistoryCount = 7

        var visibleDownloadHistory: [DownloadHistResponse] {
            isDownloadHistoryExpanded
                ? downloadHistory
                : Array(downloadHistory.prefix(Self.collapsedHistoryCount))
        }

        var canExpandDownloadHistory: Bool {
            downloadHistory.count > Self.collapsedHistoryCount
        }

        var downloadHistoryToggleTitle: String {
            isDownloadHistoryExpanded
                ? String.localised("generic.showLess", table: .generic)
                : String.localised("generic.showAll \(downloadHistory.count)", table: .generic)
        }

        var hasApplicationStats: Bool {
            channelStats != nil || playlistStats != nil || downloadStats != nil
        }

        var showsOverviewPlaceholder: Bool {
            videoStats == nil && !loadedSections.contains(.video)
        }

        var showsApplicationPlaceholder: Bool {
            !hasApplicationStats && !loadedSections.contains(.channel)
        }

        init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
        }
    }

    public enum Action: ViewAction {
        case view(View)
        case videoStatsResult(Result<VideoStatsResponse, Error>)
        case channelStatsResult(Result<ChannelStatsResponse, Error>)
        case playlistStatsResult(Result<PlaylistStatsResponse, Error>)
        case downloadStatsResult(Result<DownloadStatsResponse, Error>)
        case watchStatsResult(Result<WatchStatsResponse, Error>)
        case biggestChannelsResult(Result<[BiggestChannelResponse], Error>)
        case downloadHistoryResult(Result<[DownloadHistResponse], Error>)

        @CasePathable
        public enum View {
            case viewDidAppear
            case downloadHistoryToggleTapped
        }
    }

    @Dependency(\.statsService) var statsService

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }

}
