import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum StatsSection: Hashable, Sendable {
    case video, channel, playlist, download, watch, biggestChannels
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
        var isLoading = false
        var hasLoaded = false
        var loadedSections: Set<StatsSection> = []
    }

    public enum Action: ViewAction {
        case view(View)
        case videoStatsLoaded(VideoStatsResponse)
        case channelStatsLoaded(ChannelStatsResponse)
        case playlistStatsLoaded(PlaylistStatsResponse)
        case downloadStatsLoaded(DownloadStatsResponse)
        case watchStatsLoaded(WatchStatsResponse)
        case biggestChannelsLoaded([BiggestChannelResponse])
        case statsFailed(StatsSection)

        @CasePathable
        public enum View {
            case viewDidAppear
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
