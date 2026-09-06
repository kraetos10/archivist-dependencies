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
    #if !os(tvOS)
    case deviceDownloads
    #endif
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
        #if !os(tvOS)
        public var deviceDownloads: DeviceDownloadsReducer.State
        #endif
        public var settings: SettingsReducer.State
        @Shared(.appStorage(ChildMode.enabledKey)) public var childModeEnabled = false
        @Shared(.appStorage(ChildMode.pinKey)) public var childModePin = ""
        public var settingsUnlocked: Bool = false
        public var isPresentingSettingsPin: Bool = false
        #if os(iOS)
        /// Video handed over by a detail screen the user dragged down, so
        /// playback can carry on in the floating mini player. It lives here
        /// rather than in the presenting feature because the mini player
        /// has to outlive whichever tab's navigation stack the detail was
        /// pushed onto.
        public var miniPlayer: VideoDetailReducer.State?
        /// False while the mini player has been tapped back up to a full
        /// detail screen.
        public var isMiniPlayerMinimised = true
        #endif
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
            #if os(tvOS)
            videoList.videoDetail?.video.videoId
                ?? channels.videoDetail?.video.videoId
                ?? playlists.videoDetail?.video.videoId
                ?? settings.videoDetail?.video.videoId
            #else
            videoList.videoDetail?.video.videoId
                ?? channels.videoDetail?.video.videoId
                ?? playlists.videoDetail?.video.videoId
                ?? deviceDownloads.videoDetail?.video.videoId
                ?? settings.videoDetail?.video.videoId
            #endif
        }

        #if os(iOS)
        /// Identity of what the mini player overlays are showing, so they
        /// can animate in and out of the reducer-driven changes. `State`
        /// isn't `Equatable`, so `.animation(value:)` needs a scalar.
        var miniPlayerAnimationKey: String? {
            guard let miniPlayer else { return nil }
            return "\(miniPlayer.video.videoId)-\(isMiniPlayerMinimised)"
        }
        #endif

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
            #if !os(tvOS)
            self.deviceDownloads = DeviceDownloadsReducer.State(serverConfig: serverConfig)
            #endif
            self.settings = SettingsReducer.State(serverConfig: serverConfig, supportURL: supportURL)
            #if os(tvOS)
            self.search = TVSearchReducer.State(serverConfig: serverConfig)
            #endif
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case selectTab(AppTab?)
        case settingsPinSucceeded
        case settingsPinDismissed
        case appeared
        case scenePhaseChanged(ScenePhase)
        case homeChannelTapped(ChannelResponse)
        case homePlaylistTapped(PlaylistResponse)
        case videoList(VideoListReducer.Action)
        case channels(ChannelsReducer.Action)
        case playlists(PlaylistsReducer.Action)
        case queue(DownloadsReducer.Action)
        #if !os(tvOS)
        case deviceDownloads(DeviceDownloadsReducer.Action)
        #endif
        case settings(SettingsReducer.Action)
        #if os(iOS)
        case minimizePlayerRequested(VideoDetailReducer.State)
        case miniPlayerTapped
        case miniPlayerCloseTapped
        case miniPlayerFinished
        case miniPlayer(VideoDetailReducer.Action)
        case playerSuperseded(previousVideoId: String, position: Int)
        #endif
        #if os(tvOS)
        case search(TVSearchReducer.Action)
        case setPresentingAllChannels(Bool)
        case setPresentingAllPlaylists(Bool)
        #endif
    }

    #if os(iOS)
    enum CancelID {
        /// Watches for another video taking over the player while the mini
        /// player is up. Kept on the tab's own ID rather than the video
        /// detail's, whose `CancelID.playback` the incoming video cancels.
        case miniPlayerSupersession
        /// Subscription to `MinimizePlayerClient`. `.appeared` can fire
        /// more than once, and a second subscription would install the
        /// same mini player twice.
        case minimizeRequests
    }
    #endif

    @Dependency(\.continuousClock) var clock
    @Dependency(\.videoService) var videoService
    #if os(iOS)
    @Dependency(\.minimizePlayer) var minimizePlayer
    #endif

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.isPresentingSettingsPin):
                if !state.isPresentingSettingsPin, !state.settingsUnlocked {
                    state.selectedTab = .home
                }
                return .none
            case .binding:
                return .none
            case .selectTab(let tab):
                if tab != .settings {
                    state.settingsUnlocked = false
                }
                if tab == .settings,
                   state.childModeEnabled,
                   !state.childModePin.isEmpty,
                   !state.settingsUnlocked {
                    state.isPresentingSettingsPin = true
                    state.selectedTab = tab
                    return .none
                }
                state.selectedTab = tab
                return .none
            case .settingsPinSucceeded:
                state.settingsUnlocked = true
                state.isPresentingSettingsPin = false
                return .none
            case .settingsPinDismissed:
                state.isPresentingSettingsPin = false
                if !state.settingsUnlocked {
                    state.selectedTab = .home
                }
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
            #if os(iOS)
            case .minimizePlayerRequested(let detail):
                return handleMinimizePlayerRequested(detail, state: &state)
            case .miniPlayerTapped:
                return handleMiniPlayerTapped(state: &state)
            case .miniPlayerCloseTapped:
                return handleMiniPlayerClosed(state: &state)
            case .miniPlayer(.delegate(.didRequestMinimize)):
                return handleMiniPlayerReminimised(state: &state)
            // Closing from the expanded mini player, deleting the video on
            // the server, or running out of videos to auto-advance to all
            // leave nothing to keep playing — so the mini player goes away.
            //
            // Deferred through a separate action rather than cleared here:
            // this reducer runs before the `ifLet` below, so clearing the
            // state now would drop the same action on the floor before the
            // mini player's own reducer had handled it.
            case .miniPlayer(.delegate(.didDismiss)),
                 .miniPlayer(.serverDeleteResult(.success)),
                 .miniPlayer(.autoPlayExhausted):
                return .send(.miniPlayerFinished)
            case .miniPlayerFinished:
                return handleMiniPlayerFinished(state: &state)
            case .miniPlayer:
                return .none
            case .playerSuperseded(let previousVideoId, let position):
                return handlePlayerSuperseded(
                    previousVideoId: previousVideoId,
                    position: position,
                    state: &state
                )
            #endif
            case .videoList, .channels, .playlists, .queue, .settings:
                return .none
            #if !os(tvOS)
            case .deviceDownloads:
                return .none
            #endif
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
        #if os(iOS)
        .ifLet(\.miniPlayer, action: \.miniPlayer) {
            VideoDetailReducer()
        }
        #endif
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
        #if !os(tvOS)
        Scope(state: \.deviceDownloads, action: \.deviceDownloads) {
            DeviceDownloadsReducer()
        }
        #endif
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
