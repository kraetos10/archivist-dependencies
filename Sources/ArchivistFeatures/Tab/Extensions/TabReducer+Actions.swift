import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

extension TabReducer {
    func handleAppeared(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let shouldSync = state.settings.checkForChannelUpdates
        // Wire PlayerManager callbacks to TCA services so the player layer
        // can request minimize / restore without holding TCA dependencies.
        let restoreService = pipRestoreService
        let minimizeService = pipMinimizeService
        Task { @MainActor in
            PlayerManager.shared.onPiPRestore = {
                Task { await restoreService.request() }
            }
            PlayerManager.shared.onPiPStartRequested = {
                Task { await minimizeService.request() }
            }
        }
        var effects: [Effect<Action>] = [
            .send(.settings(.activeTask(.view(.startPolling)))),
            .run { [pipRestoreService] send in
                for await requested in await pipRestoreService.subscribe() {
                    guard requested else { continue }
                    await pipRestoreService.consume()
                    await send(.miniPlayerTapped)
                }
            },
            .run { [pipMinimizeService] send in
                for await requested in await pipMinimizeService.subscribe() {
                    guard requested else { continue }
                    await pipMinimizeService.consume()
                    await send(.pipStartedMinimizeRequested)
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

    // MARK: - Mini Player

    func handleMinimizeVideoDetail(
        detail: VideoDetailReducer.State,
        state: inout State
    ) -> Effect<Action> {
        state.miniPlayerDetail = detail
        state.isMiniPlayerMinimized = true
        return .run { _ in
            await MainActor.run {
                PlayerManager.shared.activePlayerSurfaceRole = .mini
            }
        }
    }

    func handleMiniPlayerTapped(state: inout State) -> Effect<Action> {
        guard state.miniPlayerDetail != nil else { return .none }
        state.miniPlayerDetail?.isPlaying = true
        state.isMiniPlayerMinimized = false
        return .run { _ in
            await MainActor.run {
                PlayerManager.shared.activePlayerSurfaceRole = .fullDetail
            }
        }
    }

    /// Called when PiP starts (from any backend). Finds whichever video detail
    /// is currently presented across the tabs and minimizes it so a mini
    /// player exists in state — that gives the persistent player surface
    /// somewhere to be reparented when the user taps PiP restore.
    func handlePiPStartedMinimizeRequested(state: inout State) -> Effect<Action> {
        // Already minimized → nothing to do.
        if state.miniPlayerDetail != nil { return .none }

        if let detail = state.videoList.videoDetail {
            state.videoList.videoDetail = nil
            return handleMinimizeVideoDetail(detail: detail, state: &state)
        }
        if let detail = state.videoList.presentedVideo {
            state.videoList.presentedVideo = nil
            return handleMinimizeVideoDetail(detail: detail, state: &state)
        }
        if let detail = state.videoList.selectedVideo {
            state.videoList.selectedVideo = nil
            return handleMinimizeVideoDetail(detail: detail, state: &state)
        }
        if let detail = state.channels.videoDetail {
            state.channels.videoDetail = nil
            return handleMinimizeVideoDetail(detail: detail, state: &state)
        }
        if let detail = state.playlists.videoDetail {
            state.playlists.videoDetail = nil
            return handleMinimizeVideoDetail(detail: detail, state: &state)
        }
        if let detail = state.settings.videoDetail {
            state.settings.videoDetail = nil
            return handleMinimizeVideoDetail(detail: detail, state: &state)
        }
        return .none
    }

    func handleMiniPlayerCloseTapped(state: inout State) -> Effect<Action> {
        let detail = state.miniPlayerDetail
        state.miniPlayerDetail = nil
        state.isMiniPlayerMinimized = false
        return .merge(
            .run { _ in
                await MainActor.run {
                    PlayerManager.shared.stop()
                }
            },
            .run { [videoService] _ in
                guard let detail else { return }
                let position = await Int(PlayerManager.shared.currentTime)
                guard position > 0 else { return }
                try? await videoService.setProgress(
                    config: detail.serverConfig,
                    videoId: detail.video.videoId,
                    position: position
                )
            }
        )
    }

}
