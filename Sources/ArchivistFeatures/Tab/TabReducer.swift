import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries
import SwiftUI

public enum AppTab: Hashable, Sendable {
    case home
    case channels
    case playlists
    case queue
    #if !os(tvOS)
    case deviceDownloads
    #endif
    #if os(tvOS)
    /// tvOS has a Search tab in place of the Channels and Playlists tabs.
    case search
    #endif
    case settings
}

@Reducer
public struct TabReducer {
    public init() {}
    @ObservableState
    public struct State: Equatable, Sendable {
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
        #if !os(tvOS)
        /// Videos currently downloading to the device, so the Saved tab can
        /// badge them. Live count query: it updates as downloads start and
        /// finish without the tab asking. Zero draws no badge.
        @FetchOne(DeviceDownload.where { $0.status.eq(DeviceDownloadStatus.downloading) }.count())
        public var activeDeviceDownloadCount = 0
        #endif
        @Shared(.childModeEnabled) public var childModeEnabled
        public var settingsUnlocked: Bool = false
        @Presents var settingsPin: PinEntryReducer.State?
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

        /// Settings shows a lock placeholder until the PIN is entered.
        var isSettingsLocked: Bool {
            childModeEnabled && !settingsUnlocked
        }

        /// One badge while the server is working through a download.
        var settingsBadgeCount: Int {
            activeDownload == nil ? 0 : 1
        }

        var hasVideoDetailPresented: Bool {
            presentedVideoDetailVideoId != nil
        }

        var presentedVideoDetailVideoId: String? {
            #if os(tvOS)
            videoList.destination?.videoDetail?.video.videoId
                ?? channels.videoDetail?.video.videoId
                ?? playlists.videoDetail?.video.videoId
                ?? settings.videoDetail?.video.videoId
            #else
            videoList.destination?.videoDetail?.video.videoId
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

        /// Opens a video over the Home tab — the entry point for deep links
        /// and Top Shelf items, which arrive from outside any screen.
        public mutating func openVideoOnHome(_ video: VideoResponse) {
            selectedTab = .home
            settingsUnlocked = false
            @Shared(.autoPlayEnabled) var autoPlayEnabled
            let detail = VideoDetailReducer.State(
                serverConfig: videoList.serverConfig,
                video: video,
                nextVideos: [],
                shouldAutoPlayNextVideo: autoPlayEnabled
            )
            #if os(tvOS)
            videoList.path.append(.videoDetail(detail))
            #else
            videoList.destination = .videoDetail(detail)
            #endif
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case selectTab(AppTab?)
        case settingsPin(PresentationAction<PinEntryReducer.Action>)
        case settingsPinLoaded(String?)
        case appeared
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
        case miniPlayerRequested(MiniPlayerRequest)
        case miniPlayerTapped
        case miniPlayerCloseTapped
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
        /// Subscription to `MiniPlayerClient`. `.appeared` can fire more
        /// than once, and a second subscription would act on the same
        /// request twice.
        case miniPlayerRequests
    }
    #endif

    @Dependency(\.pinStore) var pinStore
    @Dependency(\.videoService) var videoService
    #if os(iOS)
    @Dependency(\.miniPlayerClient) var miniPlayerClient
    @Dependency(\.playerClient) var playerClient
    #endif

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .selectTab(let tab):
                return handleSelectTab(tab, state: &state)
            case .settingsPinLoaded(let pin):
                return handleSettingsPinLoaded(pin, state: &state)
            case .settingsPin(.presented(.succeeded)):
                state.settingsUnlocked = true
                state.settingsPin = nil
                return .none
            case .settingsPin(.presented(.cancelled)), .settingsPin(.dismiss):
                state.settingsPin = nil
                if !state.settingsUnlocked {
                    state.selectedTab = .home
                }
                return .none
            case .settingsPin:
                return .none
            case .appeared:
                return handleAppeared(state: &state)

            case .homeChannelTapped(let channel):
                state.channels.selectedChannel = ChannelDetailReducer.State(
                    serverConfig: state.channels.serverConfig,
                    channel: channel
                )
                return .none

            case .homePlaylistTapped(let playlist):
                state.playlists.selectedPlaylist = PlaylistDetailReducer.State(
                    serverConfig: state.playlists.serverConfig,
                    playlist: playlist
                )
                return .none

            case .settings(.path(.element(
                    _,
                    action: .downloads(.downloadDetail(.presented(.delegate(.didQueueDownload))))
                 ))),
                 .queue(.downloadDetail(.presented(.delegate(.didQueueDownload)))),
                 // tvOS bumps a queue item by tapping the alert's
                 // "Download Now" — there's no `downloadDetail` screen
                 // in that flow, so the iOS path above never matches.
                 // Without this case the `ActiveTaskView` row in tvOS
                 // settings stays empty even while the server is busy.
                 .queue(.alert(.presented(.confirmDownload))),
                 .channels(.channelDetail(.presented(.downloadDetail(.presented(.delegate(.didQueueDownload)))))),
                 .channels(.path(.element(
                    _,
                    action: .channelDetail(.downloadDetail(.presented(.delegate(.didQueueDownload))))
                 ))),
                 .videoList(.destination(.presented(.addVideo(.addResult(.success))))):
                return .send(.settings(.activeTask(.startPolling)))

            case .settings(.activeTask(.downloadCompleted)):
                #if os(tvOS)
                return .merge(
                    .send(.channels(.refreshPendingDownloads)),
                    .send(.search(.refreshPendingDownloads))
                )
                #else
                return .send(.channels(.refreshPendingDownloads))
                #endif

            #if os(iOS)
            case .miniPlayerRequested(let request):
                return handleMiniPlayerRequest(request, state: &state)
            case .miniPlayerTapped:
                return handleMiniPlayerTapped(state: &state)
            case .miniPlayerCloseTapped:
                return handleMiniPlayerClosed(state: &state)
            case .miniPlayer(.delegate(.didRequestMinimize)):
                return handleMiniPlayerReminimised(state: &state)
            // Closing from the expanded mini player, deleting the video on
            // the server, or running out of videos to auto-advance to all
            // leave nothing to keep playing — so the mini player goes away.
            // `ifLet` has already run the mini player's own reducer for
            // this action by the time it reaches here, so clearing the
            // state now doesn't drop the action.
            case .miniPlayer(.delegate(.didDismiss)),
                 .miniPlayer(.serverDeleteResult(.success)),
                 .miniPlayer(.autoPlayExhausted):
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
            #if os(tvOS)
            // Search opens channels and playlists over its own tab, so the
            // only thing it hands up is the server work the home screen's
            // context menu already does, through the video list's entry
            // points for it.
            case .search(.delegate(.markAsWatchedRequested(let video))):
                return .send(.videoList(.markAsWatched(video)))
            case .search(.delegate(.deleteFromServerRequested(let video))):
                return .send(.videoList(.deleteFromServer(video)))
            case .search(.destination(.presented(.channelDetail(.downloadDetail(.presented(.delegate(.didQueueDownload))))))):
                return .send(.settings(.activeTask(.startPolling)))
            case .search:
                return .none
            // A mark-watched from Search lands here once the server has
            // the new state; pass it on so the result card updates too.
            case .videoList(.videoRefreshed(let video)):
                return .send(.search(.videoUpdated(video)))
            #endif
            case .videoList, .channels, .playlists, .queue, .settings:
                return .none
            #if !os(tvOS)
            case .deviceDownloads:
                return .none
            #endif
            #if os(tvOS)
            case .setPresentingAllChannels(let presenting):
                state.presentingAllChannels = presenting
                return .none
            case .setPresentingAllPlaylists(let presenting):
                state.presentingAllPlaylists = presenting
                return .none
            #endif
            }
        }
        .ifLet(\.$settingsPin, action: \.settingsPin) {
            PinEntryReducer()
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
