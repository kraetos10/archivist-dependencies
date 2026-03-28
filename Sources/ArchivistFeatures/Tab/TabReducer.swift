import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum AppTab: Hashable, Sendable {
    case home
    case channels
    case playlists
    case settings
}

public struct MiniPlayerState: Equatable, Sendable {
    public var video: VideoResponse
    public var serverConfig: ServerConfig
    public var nextVideos: [VideoResponse]
    public var showPlayNext: Bool

    public init(video: VideoResponse, serverConfig: ServerConfig, nextVideos: [VideoResponse] = [], showPlayNext: Bool = true) {
        self.video = video
        self.serverConfig = serverConfig
        self.nextVideos = nextVideos
        self.showPlayNext = showPlayNext
    }
}

@Reducer
public struct TabReducer {
    public init() {}
    @ObservableState
    public struct State: Sendable {
        public var selectedTab: AppTab? = .home
        public var serverConfig: ServerConfig
        public var videoList: VideoListReducer.State
        public var channels: ChannelsReducer.State
        public var playlists: PlaylistsReducer.State
        public var settings: SettingsReducer.State
        public var miniPlayer: MiniPlayerState?

        public var activeDownload: ActiveDownload? {
            settings.activeTask.activeDownload
        }

        public init(serverConfig: ServerConfig) {
            self.serverConfig = serverConfig
            self.videoList = VideoListReducer.State(serverConfig: serverConfig)
            self.channels = ChannelsReducer.State(serverConfig: serverConfig)
            self.playlists = PlaylistsReducer.State(serverConfig: serverConfig)
            self.settings = SettingsReducer.State(serverConfig: serverConfig)
        }
    }

    public enum Action {
        case selectTab(AppTab?)
        case appeared
        case miniPlayerTapped
        case miniPlayerPlayPauseTapped
        case miniPlayerCloseTapped
        case showMiniPlayer(VideoResponse, [VideoResponse], ServerConfig, Bool)
        case videoList(VideoListReducer.Action)
        case channels(ChannelsReducer.Action)
        case playlists(PlaylistsReducer.Action)
        case settings(SettingsReducer.Action)
    }

    @Dependency(\.pipRestoreService) var pipRestoreService

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .selectTab(let tab):
                state.selectedTab = tab
                return .none
            case .appeared:
                return handleAppeared(state: &state)
            case .showMiniPlayer(let video, let nextVideos, let config, let showPlayNext):
                return handleShowMiniPlayer(video, nextVideos, config, showPlayNext, state: &state)
            case .miniPlayerTapped:
                return handleMiniPlayerTapped(state: &state)
            case .miniPlayerPlayPauseTapped:
                return handleMiniPlayerPlayPauseTapped(state: &state)
            case .miniPlayerCloseTapped:
                return handleMiniPlayerCloseTapped(state: &state)

            case .settings(.downloads(.downloadDetail(.presented(.downloadResult(.success))))),
                 .channels(.channelDetail(.presented(.downloadDetail(.presented(.downloadResult(.success)))))),
                 .channels(.path(.element(_, action: .channelDetail(.downloadDetail(.presented(.downloadResult(.success))))))):
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .settings(.activeTask(.downloadCompleted)):
                return .send(.channels(.refreshPendingDownloads))

            case .videoList(.selectedVideoDetail(.delegate(.didRequestMinimize(let video, let nextVideos, let config, let showPlayNext)))),
                 .videoList(.presentedVideo(.presented(.delegate(.didRequestMinimize(let video, let nextVideos, let config, let showPlayNext))))),
                 .videoList(.videoDetail(.presented(.delegate(.didRequestMinimize(let video, let nextVideos, let config, let showPlayNext))))),
                 .channels(.videoDetail(.presented(.delegate(.didRequestMinimize(let video, let nextVideos, let config, let showPlayNext))))),
                 .playlists(.videoDetail(.presented(.delegate(.didRequestMinimize(let video, let nextVideos, let config, let showPlayNext))))),
                 .settings(.videoDetail(.presented(.delegate(.didRequestMinimize(let video, let nextVideos, let config, let showPlayNext))))):
                return .send(.showMiniPlayer(video, nextVideos, config, showPlayNext))

            case .videoList, .channels, .playlists, .settings:
                return .none
            }
        }
        Scope(state: \.videoList, action: \.videoList) {
            VideoListReducer()
        }
        Scope(state: \.channels, action: \.channels) {
            ChannelsReducer()
        }
        Scope(state: \.playlists, action: \.playlists) {
            PlaylistsReducer()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsReducer()
        }
    }
}
