import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

extension TabReducer {
    func handleAppeared(state: inout State) -> Effect<Action> {
        #if os(iOS)
        return .merge(
            .send(.settings(.activeTask(.view(.startPolling)))),
            // Detail screens publish their mini-player requests here
            // rather than through a delegate chain — see `MiniPlayerClient`
            // for why. This subscription is what makes the tab the owner
            // of the mini player regardless of which tab the detail was
            // pushed onto.
            .run { [miniPlayerClient] send in
                for await request in await miniPlayerClient.subscribe() {
                    guard let request else { continue }
                    await miniPlayerClient.consume()
                    await send(.miniPlayerRequested(request))
                }
            }
            .cancellable(id: CancelID.miniPlayerRequests, cancelInFlight: true)
        )
        #else
        return .send(.settings(.activeTask(.view(.startPolling))))
        #endif
    }

    func handleScenePhaseChanged(
        _ phase: ScenePhase,
        state: inout State
    ) -> Effect<Action> {
        // VLC handles background playback natively via the
        // `UIBackgroundModes: audio` entitlement + AVAudioSession `.playback`,
        // so no scene-phase intervention is required here.
        _ = phase
        return .none
    }

    #if os(iOS)
    // MARK: - Mini Player

    func handleMiniPlayerRequest(
        _ request: MiniPlayerRequest,
        state: inout State
    ) -> Effect<Action> {
        switch request {
        case .minimise(let detail):
            return handleMinimiseRequested(detail, state: &state)
        case .detailAppeared(let videoId):
            return handleDetailAppeared(videoId: videoId, state: &state)
        }
    }

    /// A video detail screen came on screen while the mini player was up.
    /// Both host the same player surface, so the mini player stands down.
    ///
    /// If the screen is for the video the mini player was playing, hand the
    /// running playback over rather than stopping it — the screen's
    /// `viewDidAppear` adopts it, and the user sees it carry on. Any other
    /// video means the mini player's video is genuinely finished with, so
    /// stop it and write a resume position.
    func handleDetailAppeared(
        videoId: String,
        state: inout State
    ) -> Effect<Action> {
        guard let mini = state.miniPlayer else { return .none }
        guard mini.video.videoId == videoId else {
            return handleMiniPlayerClosed(state: &state)
        }
        state.miniPlayer = nil
        state.isMiniPlayerMinimised = true
        return .merge(
            .cancel(id: CancelID.miniPlayerSupersession),
            .run { _ in
                await MainActor.run {
                    PlayerManager.shared.activePlayerSurfaceRole = .fullDetail
                }
            }
        )
    }

    /// Takes ownership of a detail screen that was dragged down, so its
    /// video keeps playing in the floating mini player.
    func handleMinimiseRequested(
        _ detail: VideoDetailReducer.State,
        state: inout State
    ) -> Effect<Action> {
        var detail = detail
        detail.isHostedInMiniPlayer = true
        detail.isMiniPlayerCollapsed = true
        state.miniPlayer = detail
        state.isMiniPlayerMinimised = true
        return .merge(
            .run { _ in
                await MainActor.run {
                    PlayerManager.shared.activePlayerSurfaceRole = .mini
                }
            },
            // The originating screen's playback effect died with its
            // store, taking the `PlayerManager.events` subscription with
            // it. Without a fresh one the mini player would keep rendering
            // but stop saving progress and stop auto-advancing.
            .send(.miniPlayer(.resumePlaybackObservation)),
            watchForSupersessionEffect()
        )
    }

    /// Watches for another video taking over the player while the mini
    /// player is up — the user opening something else from any tab.
    /// `PlayerManager.load` reassigns the player surface to the full detail
    /// container, so without this the mini player would sit there black,
    /// captioned with a video that is no longer playing.
    ///
    /// This can't ride on the mini player's own event subscription: that
    /// uses `VideoDetailReducer.CancelID.playback`, which the incoming
    /// video's playback effect cancels with `cancelInFlight` before the
    /// event is ever emitted.
    private func watchForSupersessionEffect() -> Effect<Action> {
        .run { send in
            let events = await MainActor.run { PlayerManager.shared.events }
            for await event in events {
                guard case .supersededByNewMedia(let previousVideoId, let position, _) = event
                else { continue }
                await send(
                    .playerSuperseded(
                        previousVideoId: previousVideoId,
                        position: position
                    )
                )
            }
        }
        .cancellable(id: CancelID.miniPlayerSupersession, cancelInFlight: true)
    }

    /// Retires the mini player when a *different* screen loads something
    /// else.
    ///
    /// The mini player advancing to its own next video looks identical from
    /// the player's side, so the two are told apart by state: on its own
    /// advance the mini player has already moved on to the new video, so
    /// `previousVideoId` no longer matches what it holds.
    func handlePlayerSuperseded(
        previousVideoId: String,
        position: Int,
        state: inout State
    ) -> Effect<Action> {
        guard let mini = state.miniPlayer,
              mini.video.videoId == previousVideoId
        else { return .none }

        let config = mini.serverConfig
        state.miniPlayer = nil
        state.isMiniPlayerMinimised = true
        return .merge(
            .cancel(id: CancelID.miniPlayerSupersession),
            // The mini player's own event subscription is already gone by
            // now, so the outgoing resume position has to be written here.
            .run { [videoService] _ in
                guard position > 0 else { return }
                try? await videoService.setProgress(
                    config: config,
                    videoId: previousVideoId,
                    position: position
                )
            }
        )
    }

    /// Expands the mini player back into a full detail screen. The
    /// persistent VLC surface is reparented, not reloaded, so playback
    /// doesn't skip.
    func handleMiniPlayerTapped(state: inout State) -> Effect<Action> {
        guard state.miniPlayer != nil else { return .none }
        state.isMiniPlayerMinimised = false
        state.miniPlayer?.isMiniPlayerCollapsed = false
        return .run { _ in
            await MainActor.run {
                PlayerManager.shared.activePlayerSurfaceRole = .fullDetail
            }
        }
    }

    /// The expanded mini player was dragged back down.
    func handleMiniPlayerReminimised(state: inout State) -> Effect<Action> {
        guard state.miniPlayer != nil else { return .none }
        state.isMiniPlayerMinimised = true
        state.miniPlayer?.isMiniPlayerCollapsed = true
        return .none
    }

    /// Tearing the mini player down when the video itself is done —
    /// playback already stopped, so there's nothing left to save.
    func handleMiniPlayerFinished(state: inout State) -> Effect<Action> {
        state.miniPlayer = nil
        state.isMiniPlayerMinimised = true
        return .merge(
            .cancel(id: CancelID.miniPlayerSupersession),
            .run { _ in
                await MainActor.run {
                    PlayerManager.shared.activePlayerSurfaceRole = .fullDetail
                }
            }
        )
    }

    /// The user dismissed the mini player itself. Playback is still
    /// running, so the resume position has to be read *before* `stop()`
    /// zeroes it — and saved from here rather than off the player's
    /// `.paused` event, because clearing `miniPlayer` cancels the
    /// subscription that would have handled it.
    func handleMiniPlayerClosed(state: inout State) -> Effect<Action> {
        let detail = state.miniPlayer
        state.miniPlayer = nil
        state.isMiniPlayerMinimised = true
        return .merge(
            .cancel(id: CancelID.miniPlayerSupersession),
            .run { [videoService] _ in
                let position = await MainActor.run { Int(PlayerManager.shared.currentTime) }
                await MainActor.run {
                    PlayerManager.shared.activePlayerSurfaceRole = .fullDetail
                    PlayerManager.shared.stop()
                }
                guard let detail, position > 0 else { return }
                try? await videoService.setProgress(
                    config: detail.serverConfig,
                    videoId: detail.video.videoId,
                    position: position
                )
            }
        )
    }
    #endif
}
