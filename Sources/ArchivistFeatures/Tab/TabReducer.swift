import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
import SwiftUI

public enum AppTab: Hashable, Sendable {
    case home
    case channels
    case playlists
    case queue
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
        public var queue: DownloadsReducer.State
        public var settings: SettingsReducer.State
        #if os(tvOS)
        public var search: TVSearchReducer.State
        /// True when the "View All" channels destination is presented as a
        /// full-screen cover from the tvOS home screen. tvOS doesn't expose
        /// a Channels tab, so this reuses the existing `TVChannelsScreen`
        /// inside a cover instead of switching tabs.
        public var presentingAllChannels: Bool = false
        public var presentingAllPlaylists: Bool = false
        #endif

        var hasVideoDetailPresented: Bool {
            presentedVideoDetailVideoId != nil
        }

        var presentedVideoDetailVideoId: String? {
            videoList.videoDetail?.video.videoId
                ?? channels.videoDetail?.video.videoId
                ?? playlists.videoDetail?.video.videoId
                ?? settings.videoDetail?.video.videoId
        }

        public var activeDownload: ActiveDownload? {
            settings.activeTask.activeDownload
        }

        public init(
            serverConfig: ServerConfig,
            supportURL: URL? = nil
        ) {
            self.serverConfig = serverConfig
            self.videoList = VideoListReducer.State(serverConfig: serverConfig)
            self.channels = ChannelsReducer.State(serverConfig: serverConfig)
            self.playlists = PlaylistsReducer.State(serverConfig: serverConfig)
            self.queue = DownloadsReducer.State(serverConfig: serverConfig)
            self.settings = SettingsReducer.State(serverConfig: serverConfig, supportURL: supportURL)
            #if os(tvOS)
            self.search = TVSearchReducer.State(serverConfig: serverConfig)
            #endif
        }
    }

    public enum Action {
        case selectTab(AppTab?)
        case appeared
        case scenePhaseChanged(ScenePhase)
        case homeChannelTapped(ChannelResponse)
        case homePlaylistTapped(PlaylistResponse)
        case videoList(VideoListReducer.Action)
        case channels(ChannelsReducer.Action)
        case playlists(PlaylistsReducer.Action)
        case queue(DownloadsReducer.Action)
        case settings(SettingsReducer.Action)
        #if os(tvOS)
        case search(TVSearchReducer.Action)
        case setPresentingAllChannels(Bool)
        case setPresentingAllPlaylists(Bool)
        #endif
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.videoService) var videoService

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .selectTab(let tab):
                state.selectedTab = tab
                return .none
            case .appeared:
                return handleAppeared(state: &state)
            case .scenePhaseChanged(let phase):
                return handleScenePhaseChanged(phase, state: &state)

            case .homeChannelTapped(let channel):
                let detailState = ChannelDetailReducer.State(
                    serverConfig: state.channels.serverConfig,
                    channel: channel
                )
                state.channels.selectedChannel = detailState
                return .none

            case .homePlaylistTapped(let playlist):
                state.playlists.selectedPlaylist = PlaylistDetailReducer.State(
                    serverConfig: state.playlists.serverConfig,
                    playlist: playlist
                )
                return .none

            case .settings(.path(.element(
                    _,
                    action: .downloads(.downloadDetail(.presented(.downloadResult(.success))))
                 ))),
                 .queue(.downloadDetail(.presented(.downloadResult(.success)))),
                 // tvOS bumps a queue item by tapping the alert's
                 // "Download Now" — there's no `downloadDetail` screen
                 // in that flow, so the iOS path above never matches.
                 // Without this case the `ActiveTaskView` row in tvOS
                 // settings stays empty even while the server is busy.
                 .queue(.alert(.presented(.confirmDownload))),
                 .channels(.channelDetail(.presented(.downloadDetail(.presented(.downloadResult(.success)))))),
                 .channels(.path(.element(
                    _,
                    action: .channelDetail(.downloadDetail(.presented(.downloadResult(.success))))
                 ))),
                 .videoList(.addVideo(.presented(.addResult(.success)))):
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .settings(.activeTask(.downloadCompleted)):
                return .send(.channels(.refreshPendingDownloads))

            // Mini-player minimize hooks were removed when we switched to
            // system PiP for minimize. Each VideoDetail dismiss now hands
            // off via `PlayerManager.startPiPIfAvailable()` and falls
            // through to a normal `didDismiss`.
            case .videoList, .channels, .playlists, .queue, .settings:
                return .none
            #if os(tvOS)
            case .search(.delegate(.showChannel(let channel))):
                return .send(.homeChannelTapped(channel))
            case .search(.delegate(.showPlaylist(let playlist))):
                return .send(.homePlaylistTapped(playlist))
            case .search:
                return .none
            case .setPresentingAllChannels(let presenting):
                state.presentingAllChannels = presenting
                return .none
            case .setPresentingAllPlaylists(let presenting):
                state.presentingAllPlaylists = presenting
                return .none
            #endif
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
        Scope(state: \.queue, action: \.queue) {
            DownloadsReducer()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsReducer()
        }
        #if os(tvOS)
        Scope(state: \.search, action: \.search) {
            TVSearchReducer()
        }
        #endif
    }
}
