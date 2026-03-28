import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
import SwiftUI

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
    public var shouldAutoPlayNextVideo: Bool

    public init(
        video: VideoResponse,
        serverConfig: ServerConfig,
        nextVideos: [VideoResponse] = [],
        showPlayNext: Bool = true,
        shouldAutoPlayNextVideo: Bool = true
    ) {
        self.video = video
        self.serverConfig = serverConfig
        self.nextVideos = nextVideos
        self.showPlayNext = showPlayNext
        self.shouldAutoPlayNextVideo = shouldAutoPlayNextVideo
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
        case miniPlayerPlayPauseTapped
        case miniPlayerCloseTapped
        case showMiniPlayer(VideoResponse, [VideoResponse], ServerConfig, Bool, Bool)
        case restoreFromMiniPlayer(MiniPlayerState)
        case homeChannelTapped(ChannelResponse)
        case homePlaylistTapped(PlaylistResponse)
        case videoList(VideoListReducer.Action)
        case channels(ChannelsReducer.Action)
        case playlists(PlaylistsReducer.Action)
        case settings(SettingsReducer.Action)
        #if os(tvOS)
        case search(TVSearchReducer.Action)
        #endif
    }

    @Dependency(\.pipRestoreService) var pipRestoreService
    @Dependency(\.newContentSyncManager) var newContentSyncManager
    @Dependency(\.continuousClock) var clock

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
            case .showMiniPlayer(let video, let nextVideos, let config, let showPlayNext, let shouldAutoPlay):
                return handleShowMiniPlayer(video, nextVideos, config, showPlayNext, shouldAutoPlay, state: &state)
            case .miniPlayerTapped:
                return handleMiniPlayerTapped(state: &state)
            case .restoreFromMiniPlayer(let mini):
                return handleRestoreFromMiniPlayer(mini, state: &state)
            case .miniPlayerPlayPauseTapped:
                return handleMiniPlayerPlayPauseTapped(state: &state)
            case .miniPlayerCloseTapped:
                return handleMiniPlayerCloseTapped(state: &state)

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
                 .channels(.channelDetail(.presented(.downloadDetail(.presented(.downloadResult(.success)))))),
                 .channels(.path(.element(
                    _,
                    action: .channelDetail(.downloadDetail(.presented(.downloadResult(.success))))
                 ))),
                 .videoList(.addVideo(.presented(.addResult(.success)))):
                return .send(.settings(.activeTask(.view(.startPolling))))

            case .settings(.activeTask(.downloadCompleted)):
                return .send(.channels(.refreshPendingDownloads))

            case let .videoList(.selectedVideoDetail(.delegate(
                    .didRequestMinimize(video, nextVideos, config, showPlayNext, shouldAutoPlay)
                 ))),
                 let .videoList(.presentedVideo(.presented(.delegate(
                    .didRequestMinimize(video, nextVideos, config, showPlayNext, shouldAutoPlay)
                 )))),
                 let .videoList(.videoDetail(.presented(.delegate(
                    .didRequestMinimize(video, nextVideos, config, showPlayNext, shouldAutoPlay)
                 )))),
                 let .channels(.videoDetail(.presented(.delegate(
                    .didRequestMinimize(video, nextVideos, config, showPlayNext, shouldAutoPlay)
                 )))),
                 let .playlists(.videoDetail(.presented(.delegate(
                    .didRequestMinimize(video, nextVideos, config, showPlayNext, shouldAutoPlay)
                 )))),
                 let .settings(.videoDetail(.presented(.delegate(
                    .didRequestMinimize(video, nextVideos, config, showPlayNext, shouldAutoPlay)
                 )))):
                return .send(.showMiniPlayer(video, nextVideos, config, showPlayNext, shouldAutoPlay))

            case .videoList, .channels, .playlists, .settings:
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
        Scope(state: \.settings, action: \.settings) {
            SettingsReducer()
        }
        #if os(tvOS)
        Scope(state: \.search, action: \.search) {
            TVSearchReducer()
        }
        #endif

        // When a NEW video detail is presented while the mini player is active,
        // dismiss the mini player and stop the old video. Only fires when the
        // presented video is different from the one in the mini player — this
        // prevents the "restore from mini player" flow from killing playback.
        Reduce { state, _ in
            guard let mini = state.miniPlayer,
                  let presentedId = state.presentedVideoDetailVideoId,
                  presentedId != mini.video.videoId else {
                return .none
            }
            state.miniPlayer = nil
            return .run { _ in
                await MainActor.run {
                    PlayerManager.shared.stop()
                }
            }
        }
    }
}
