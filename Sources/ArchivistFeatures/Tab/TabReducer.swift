import ArchivistNetworking
import ComposableArchitecture
import Foundation

public enum AppTab: Hashable, Sendable {
    case home
    case channels
    case playlists
    case settings
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
        case videoList(VideoListReducer.Action)
        case channels(ChannelsReducer.Action)
        case playlists(PlaylistsReducer.Action)
        case settings(SettingsReducer.Action)
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .selectTab(let tab):
                state.selectedTab = tab
                return .none

            case .appeared:
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .settings(.downloads(.downloadDetail(.presented(.downloadStarted)))):
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .channels(.channelDetail(.presented(.downloadDetail(.presented(.downloadStarted))))):
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .channels(.path(.element(_, action: .channelDetail(.downloadDetail(.presented(.downloadStarted)))))):
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .settings(.activeTask(.downloadCompleted)):
                return .send(.channels(.refreshPendingDownloads))

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
