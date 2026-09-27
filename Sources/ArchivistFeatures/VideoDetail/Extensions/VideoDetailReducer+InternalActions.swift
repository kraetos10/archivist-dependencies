import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoDetailReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        if let effect = handleLoadAction(action, state: &state) {
            return effect
        }
        switch action {
        case .serverDeleteResult(let result):
            return handleServerDeleteResult(result, state: &state)
        case .watchedToggleResult(let result):
            return handleWatchedToggleResult(result, state: &state)
        case .autoPlayVideo(let video):
            return handleAutoPlayVideo(video, state: &state)
        case .autoPlayExhausted:
            return handleAutoPlayExhausted(state: &state)
        case .autoPlayCountdownStarted(let video, let consumesPlayNextQueue):
            return handleAutoPlayCountdownStarted(
                video,
                consumesPlayNextQueue: consumesPlayNextQueue,
                state: &state
            )
        case .autoPlayCountdownTick:
            return handleAutoPlayCountdownTick(state: &state)
        case .playlistLoopAdvanced(let video, let nextVideos):
            return handlePlaylistLoopAdvanced(video, nextVideos: nextVideos, state: &state)
        case .cacheStatusChanged(let isCached):
            state.isCached = isCached
            return .none
        case .playbackFailed:
            return handlePlaybackFailed(state: &state)
        case .adoptInflightPlayback:
            state.isPlaying = true
            return .none
        case .resumePlaybackObservation:
            return adoptInflightPlaybackEffect(
                config: state.serverConfig,
                videoId: state.video.videoId
            )
        default:
            return .none
        }
    }

    /// Responses from the per-video loads. Each is dropped unless it belongs
    /// to the video on screen — a switch can leave the previous video's
    /// response in flight.
    private func handleLoadAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action>? {
        switch action {
        case .videoRefreshed(let video):
            guard video.videoId == state.video.videoId else { return Effect<Action>.none }
            state.video = video
            return Effect<Action>.none
        case .commentsResult(let videoId, let result):
            guard videoId == state.video.videoId else { return Effect<Action>.none }
            return handleCommentsResult(result, state: &state)
        case .similarResult(let videoId, let result):
            guard videoId == state.video.videoId else { return Effect<Action>.none }
            return handleSimilarResult(result, state: &state)
        case .downloadResumed(let videoId, _),
             .downloadProgressUpdated(let videoId, _),
             .downloadCompleted(let videoId),
             .downloadFailed(let videoId, _):
            guard videoId == state.video.videoId else { return Effect<Action>.none }
            return handleDownloadAction(action, state: &state)
        default:
            return nil
        }
    }

    private func handleCommentsResult(
        _ result: Result<[VideoComment], Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingComments = false
        if case .success(let comments) = result {
            state.comments = comments
        }
        return .none
    }

    private func handleSimilarResult(
        _ result: Result<[VideoResponse], Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingSimilar = false
        if case .success(let videos) = result {
            state.similarVideos = videos.filter { !$0.isWatched }
        }
        return .none
    }

    private func handleDownloadAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .downloadResumed(_, let progress):
            state.isDownloading = true
            state.downloadProgress = progress
        case .downloadProgressUpdated(_, let progress):
            state.downloadProgress = progress
        case .downloadCompleted:
            state.isDownloading = false
            state.isDownloaded = true
            state.downloadProgress = 1
        case .downloadFailed(_, let message):
            state.isDownloading = false
            state.downloadError = message
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(message)
            }
        default:
            break
        }
        return .none
    }

    private func handleServerDeleteResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isDeletingFromServer = false
        switch result {
        case .success:
            state.isDownloaded = false
            return deleteLocalCopyEffect(videoId: state.video.videoId)
        case .failure(let error):
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(error.localizedDescription)
            }
            return .none
        }
    }

    private func handleWatchedToggleResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        if case .success = result {
            state.watchedOverride = !(state.watchedOverride ?? state.video.isWatched)
        }
        return .none
    }

    /// The video stopped without ever reaching its end.
    ///
    /// Deliberately not the `videoPlaybackDidEnd` path: that marks the video
    /// watched, clears its resume position and auto-advances, which is the
    /// opposite of what a video that wouldn't play deserves. Stop, say so,
    /// and offer another go.
    private func handlePlaybackFailed(state: inout State) -> Effect<Action> {
        state.isPlaying = false
        state.autoPlayCountdown = nil
        state.alert = AlertState {
            TextState(String.localised("video.playbackFailed.title", table: .videos))
        } actions: {
            ButtonState(action: .retryPlayback) {
                TextState(String.localised("video.playbackFailed.retry", table: .videos))
            }
            ButtonState(role: .cancel, action: .dismissed) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
        } message: {
            TextState(String.localised("video.playbackFailed.message", table: .videos))
        }
        return .merge(
            .cancel(id: CancelID.playback),
            .cancel(id: CancelID.autoPlayCountdown),
            .run { [playerClient] _ in
                await playerClient.stop(dismissFullscreen: true)
            }
        )
    }

    private func handleAutoPlayExhausted(state: inout State) -> Effect<Action> {
        state.isPlaying = false
        state.localWatchProgress = 1.0
        state.watchedOverride = true
        state.autoPlayCountdown = nil
        return .merge(
            .cancel(id: CancelID.playback),
            .cancel(id: CancelID.autoPlayCountdown),
            .run { [playerClient] _ in
                await playerClient.stop(dismissFullscreen: true)
            }
        )
    }

    /// Refills the up-next queue from the looping playlist, then hands off
    /// to the normal countdown so the wrap looks like any other advance.
    private func handlePlaylistLoopAdvanced(
        _ video: VideoResponse,
        nextVideos: [VideoResponse],
        state: inout State
    ) -> Effect<Action> {
        state.nextVideos = nextVideos
        return handleAutoPlayCountdownStarted(
            video,
            consumesPlayNextQueue: false,
            state: &state
        )
    }

    private func handleAutoPlayCountdownStarted(
        _ video: VideoResponse,
        consumesPlayNextQueue: Bool,
        state: inout State
    ) -> Effect<Action> {
        #if os(tvOS)
        // tvOS plays full-screen via `.fullScreenCover` — there's no
        // surface to host the countdown overlay without flashing the
        // detail screen between videos. Skip the wait and advance.
        return .run { [playNextDatabase] send in
            if consumesPlayNextQueue {
                _ = try? await playNextDatabase.popNext()
            }
            await send(.autoPlayVideo(video))
        }
        #else
        // Drop back to the thumbnail while the countdown overlay is up —
        // the video already finished so the VLC surface would otherwise
        // show a stalled black frame behind the overlay.
        state.isPlaying = false
        state.autoPlayCountdown = AutoPlayCountdown(
            nextVideo: video,
            consumesPlayNextQueue: consumesPlayNextQueue,
            remainingSeconds: Self.autoPlayCountdownSeconds
        )
        return .merge(
            .cancel(id: CancelID.playback),
            .run { [playerClient] _ in
                // Keep any presented fullscreen player up — the countdown
                // card is surfaced inside it.
                await playerClient.stop(dismissFullscreen: false)
            },
            .run { [playerClient] send in
                // Listen for the countdown card's buttons for the lifetime
                // of this countdown. The card is rendered by the fullscreen
                // player VC, which can't see the store, so it reports taps
                // through the player's event stream instead.
                let events = await playerClient.events()
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await event in events {
                            switch event {
                            case .autoPlayPlayNowTapped:
                                await send(.view(.autoPlayCountdownPlayNowTapped))
                            case .autoPlayCancelTapped:
                                await send(.view(.autoPlayCountdownCancelTapped))
                            default:
                                continue
                            }
                        }
                    }
                    // The countdown itself defines the effect's lifetime;
                    // when it runs out, tear the listener down with it so
                    // the subscription can't outlive the card.
                    for _ in 0..<Self.autoPlayCountdownSeconds {
                        try? await Task.sleep(for: .seconds(1))
                        await send(.autoPlayCountdownTick)
                    }
                    group.cancelAll()
                }
            }
            .cancellable(id: CancelID.autoPlayCountdown, cancelInFlight: true)
        )
        #endif
    }

    private func handleAutoPlayCountdownTick(state: inout State) -> Effect<Action> {
        guard var countdown = state.autoPlayCountdown else { return .none }
        countdown.remainingSeconds -= 1
        if countdown.remainingSeconds <= 0 {
            let next = countdown.nextVideo
            let consumes = countdown.consumesPlayNextQueue
            state.autoPlayCountdown = nil
            return .run { [playNextDatabase] send in
                if consumes {
                    _ = try? await playNextDatabase.popNext()
                }
                await send(.autoPlayVideo(next))
            }
        }
        state.autoPlayCountdown = countdown
        return .none
    }

    func handleAutoPlayVideo(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        // Cancel any in-flight countdown and clear its overlay state.
        state.autoPlayCountdown = nil
        // Remove the autoplayed video from the up next queue
        state.nextVideos.removeAll { $0.videoId == video.videoId }
        // Push the outgoing video onto the history stack so "previous" can
        // walk it back. Guarded to avoid duplicates in case of replays.
        if state.video.videoId != video.videoId {
            state.previousVideos.append(state.video)
        }
        let hasPrevious = !state.previousVideos.isEmpty
        state.resetForNewVideo(video)
        state.isPlaying = true
        let config = state.serverConfig
        let videoId = state.video.videoId
        // Auto-advance keeps the fullscreen player up (`replacesCurrent`)
        // so the next video plays fullscreen without a flash. The stream is
        // subscribed before the outgoing video is stopped, so its `.paused`
        // still reaches a listener: this effect's consumer filters it out
        // by `videoId`, while the outgoing video's effect — not yet
        // cancelled — saves its final position.
        let request = mediaURL(state: state).map { url in
            PlayerClient.PlaybackRequest(
                url: url,
                startPosition: state.video.resumePositionSeconds,
                videoId: videoId,
                expectedSize: state.video.mediaSize.map { Int64($0) },
                metadata: Self.nowPlayingMetadata(for: video, config: config),
                replacesCurrent: true,
                canGoPrevious: hasPrevious
            )
        }
        let playbackEffect: Effect<Action> = .run { [playerClient, videoService] send in
            guard let request else {
                await MainActor.run {
                    playerClient.stop(dismissFullscreen: false)
                    playerClient.setCanGoPrevious(hasPrevious)
                }
                return
            }
            let events = await playerClient.startPlayback(request)
            await VideoDetailReducer.observePlayback(
                events,
                videoId: videoId,
                config: config,
                videoService: videoService,
                playerClient: playerClient,
                send: send
            )
        }
        return .merge(
            .cancel(id: CancelID.autoPlayCountdown),
            .cancel(id: CancelID.autoPlayResolve),
            playbackEffect.cancellable(id: CancelID.playback, cancelInFlight: true),
            handleViewDidAppear(state: &state)
        )
    }
}
