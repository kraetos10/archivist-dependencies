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
        public var miniPlayerDetail: VideoDetailReducer.State?
        public var isMiniPlayerMinimized = false
        #if os(tvOS)
        public var search: TVSearchReducer.State
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
        case miniPlayerTapped
        case miniPlayerCloseTapped
        case pipStartedMinimizeRequested
        case miniPlayerDetail(VideoDetailReducer.Action)
        case homeChannelTapped(ChannelResponse)
        case homePlaylistTapped(PlaylistResponse)
        case videoList(VideoListReducer.Action)
        case channels(ChannelsReducer.Action)
        case playlists(PlaylistsReducer.Action)
        case queue(DownloadsReducer.Action)
        case settings(SettingsReducer.Action)
        #if os(tvOS)
        case search(TVSearchReducer.Action)
        #endif
    }

    @Dependency(\.pipRestoreService) var pipRestoreService
    @Dependency(\.pipMinimizeService) var pipMinimizeService
    @Dependency(\.newContentSyncManager) var newContentSyncManager
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
            case .miniPlayerTapped:
                return handleMiniPlayerTapped(state: &state)
            case .miniPlayerCloseTapped:
                return handleMiniPlayerCloseTapped(state: &state)
            case .pipStartedMinimizeRequested:
                return handlePiPStartedMinimizeRequested(state: &state)

            case .homeChannelTapped(let channel):
                state.channels.channelIdsWithNewContent.remove(channel.channelId)
                var detailState = ChannelDetailReducer.State(
                    serverConfig: state.channels.serverConfig,
                    channel: channel
                )
                detailState.newContentSince = UserDefaults.standard.object(
                    forKey: "newContentSync.lastLaunchDate"
                ) as? Date
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
                 .channels(.channelDetail(.presented(.downloadDetail(.presented(.downloadResult(.success)))))),
                 .channels(.path(.element(
                    _,
                    action: .channelDetail(.downloadDetail(.presented(.downloadResult(.success))))
                 ))),
                 .videoList(.addVideo(.presented(.addResult(.success)))):
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .settings(.activeTask(.downloadCompleted)):
                return .send(.channels(.refreshPendingDownloads))

            // Intercept minimize delegate from all tabs and extract the full state
            case .videoList(.selectedVideoDetail(.delegate(.didRequestMinimize))):
                guard let detail = state.videoList.selectedVideo else { return .none }
                state.videoList.selectedVideo = nil
                return handleMinimizeVideoDetail(detail: detail, state: &state)
            case .videoList(.presentedVideo(.presented(.delegate(.didRequestMinimize)))):
                guard let detail = state.videoList.presentedVideo else { return .none }
                state.videoList.presentedVideo = nil
                return handleMinimizeVideoDetail(detail: detail, state: &state)
            case .videoList(.videoDetail(.presented(.delegate(.didRequestMinimize)))):
                guard let detail = state.videoList.videoDetail else { return .none }
                state.videoList.videoDetail = nil
                return handleMinimizeVideoDetail(detail: detail, state: &state)
            case .channels(.videoDetail(.presented(.delegate(.didRequestMinimize)))):
                guard let detail = state.channels.videoDetail else { return .none }
                state.channels.videoDetail = nil
                return handleMinimizeVideoDetail(detail: detail, state: &state)
            case .playlists(.videoDetail(.presented(.delegate(.didRequestMinimize)))):
                guard let detail = state.playlists.videoDetail else { return .none }
                state.playlists.videoDetail = nil
                return handleMinimizeVideoDetail(detail: detail, state: &state)
            case .settings(.videoDetail(.presented(.delegate(.didRequestMinimize)))):
                guard let detail = state.settings.videoDetail else { return .none }
                state.settings.videoDetail = nil
                return handleMinimizeVideoDetail(detail: detail, state: &state)

            case .miniPlayerDetail(.delegate(.didRequestMinimize)):
                state.isMiniPlayerMinimized = true
                return .none
            case .miniPlayerDetail(.delegate(.didDismiss)):
                return handleMiniPlayerCloseTapped(state: &state)
            case .miniPlayerDetail:
                return .none

            case .videoList, .channels, .playlists, .queue, .settings:
                return .none
            #if os(tvOS)
            case .search(.delegate(.showChannel(let channel))):
                return .send(.homeChannelTapped(channel))
            case .search(.delegate(.showPlaylist(let playlist))):
                return .send(.homePlaylistTapped(playlist))
            case .search:
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
        EmptyReducer()
            .ifLet(\.miniPlayerDetail, action: \.miniPlayerDetail) {
                VideoDetailReducer()
            }

        // When a NEW video detail is presented while the mini player is active,
        // dismiss the mini player and stop the old video. Only fires when the
        // presented video is different from the one in the mini player — this
        // prevents the "restore from mini player" flow from killing playback.
        Reduce { state, _ in
            guard let mini = state.miniPlayerDetail,
                  let presentedId = state.presentedVideoDetailVideoId,
                  presentedId != mini.video.videoId else {
                return .none
            }
            state.miniPlayerDetail = nil
            return .run { _ in
                await MainActor.run {
                    PlayerManager.shared.stop()
                }
            }
        }
    }
}
