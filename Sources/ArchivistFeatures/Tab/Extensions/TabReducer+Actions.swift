import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

extension TabReducer {
    func handleAppeared(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let shouldSync = state.settings.checkForChannelUpdates
        var effects: [Effect<Action>] = [
            .send(.settings(.activeTask(.view(.startPolling)))),
            .run { [pipRestoreService] send in
                for await requested in await pipRestoreService.subscribe() {
                    guard requested else { continue }
                    await pipRestoreService.consume()
                    await send(.miniPlayerTapped)
                }
            }
        ]
        if shouldSync {
            effects.append(.run { [newContentSyncManager] _ in
                await newContentSyncManager.sync(config: config)
            })
        }
        return .merge(effects)
    }

    func handleScenePhaseChanged(
        _ phase: ScenePhase,
        state: inout State
    ) -> Effect<Action> {
        guard phase == .active else { return .none }
        guard state.settings.checkForChannelUpdates else { return .none }
        let config = state.serverConfig
        return .run { [newContentSyncManager] _ in
            await newContentSyncManager.sync(config: config)
        }
    }

    func handleShowMiniPlayer(
        _ video: VideoResponse,
        _ nextVideos: [VideoResponse],
        _ config: ServerConfig,
        _ showPlayNext: Bool,
        _ shouldAutoPlay: Bool,
        state: inout State
    ) -> Effect<Action> {
        state.miniPlayer = MiniPlayerState(
            video: video,
            serverConfig: config,
            nextVideos: nextVideos,
            showPlayNext: showPlayNext,
            shouldAutoPlayNextVideo: shouldAutoPlay
        )
        return .none
    }

    func handleMiniPlayerTapped(state: inout State) -> Effect<Action> {
        #if os(tvOS)
        guard let mini = state.miniPlayer else { return .none }
        state.miniPlayer = nil
        return .send(.restoreFromMiniPlayer(mini))
        #else
        // Restore from mini player
        if let mini = state.miniPlayer {
            state.miniPlayer = nil
            return .run { [clock] send in
                await MainActor.run {
                    PlayerManager.shared.stopPiP()
                }
                try? await clock.sleep(for: .milliseconds(150))
                await send(.restoreFromMiniPlayer(mini))
            }
        }

        // PiP restore without mini player — video detail is still presented.
        // Stop PiP but keep the player attached so the inline VC takes over.
        guard state.hasVideoDetailPresented else { return .none }
        return .run { _ in
            await MainActor.run {
                PlayerManager.shared.stopPiP(keepPlayer: true)
            }
        }
        #endif
    }

    func handleRestoreFromMiniPlayer(
        _ mini: MiniPlayerState,
        state: inout State
    ) -> Effect<Action> {
        let detailState = VideoDetailReducer.State(
            serverConfig: mini.serverConfig,
            video: mini.video,
            nextVideos: mini.nextVideos,
            shouldAutoPlayNextVideo: mini.shouldAutoPlayNextVideo,
            showPlayNext: mini.showPlayNext,
            isPlaying: true
        )

        // Present on whichever tab the user is currently viewing
        switch state.selectedTab {
        case .channels:
            state.channels.videoDetail = detailState
        case .playlists:
            state.playlists.videoDetail = detailState
        case .settings:
            state.settings.videoDetail = detailState
        default:
            state.videoList.videoDetail = detailState
        }
        return .run { [clock] _ in
            // Wait for the fullScreenCover presentation to complete
            // and AVPlayerViewControllerWrapper to be created
            try? await clock.sleep(for: .milliseconds(300))
            await MainActor.run {
                #if !os(tvOS)
                // Re-assign the player to the new VC in case it wasn't picked up
                PlayerManager.shared.activePlayerViewController?.player = PlayerManager.shared.player
                #endif
                let currentTime = PlayerManager.shared.currentTime
                PlayerManager.shared.seekTo(currentTime)
                PlayerManager.shared.resume()
            }
        }
    }

    func handleMiniPlayerPlayPauseTapped(state: inout State) -> Effect<Action> {
        .run { _ in
            await MainActor.run {
                PlayerManager.shared.togglePlayPause()
            }
        }
    }

    func handleMiniPlayerCloseTapped(state: inout State) -> Effect<Action> {
        let mini = state.miniPlayer
        state.miniPlayer = nil
        return .merge(
            // Stop playback immediately
            .run { _ in
                await MainActor.run {
                    PlayerManager.shared.stop()
                }
            },
            // Save progress in the background
            .run { _ in
                guard let mini else { return }
                let position = await Int(PlayerManager.shared.currentTime)
                guard position > 0 else { return }
                try? await VideoService().setProgress(
                    config: mini.serverConfig,
                    videoId: mini.video.videoId,
                    position: position
                )
            }
        )
    }
}
