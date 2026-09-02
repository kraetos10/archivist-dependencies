import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoDetailReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .videoRefreshed(let video):
            state.video = video
            return .none
        case .commentsResult(let result):
            return handleCommentsResult(result, state: &state)
        case .similarResult(let result):
            return handleSimilarResult(result, state: &state)
        case .downloadResumed, .downloadProgressUpdated, .downloadCompleted, .downloadFailed:
            return handleDownloadAction(action, state: &state)
        case .serverDeleteResult(let result):
            return handleServerDeleteResult(result, state: &state)
        case .watchedToggleResult(let result):
            return handleWatchedToggleResult(result, state: &state)
        case .loadNextVideo:
            return handleLoadNextVideo(state: &state)
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
        case .adoptInflightPlayback:
            state.isPlaying = true
            return .none
        default:
            return .none
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
        case .downloadResumed(let progress):
            state.isDownloading = true
            state.downloadProgress = progress
        case .downloadProgressUpdated(let progress):
            state.downloadProgress = progress
        case .downloadCompleted:
            state.isDownloading = false
            state.isDownloaded = true
            state.downloadProgress = 1
        case .downloadFailed(let message):
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
            let videoId = state.video.videoId
            try? localVideoStorage.deleteVideo(videoId: videoId)
            try? deviceDownloadDatabase.deleteDownload(videoId)
            state.isDownloaded = false
        case .failure(let error):
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(error.localizedDescription)
            }
        }
        return .none
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

    private func handleAutoPlayExhausted(state: inout State) -> Effect<Action> {
        state.isPlaying = false
        state.localWatchProgress = 1.0
        state.watchedOverride = true
        state.autoPlayCountdown = nil
        return .merge(
            .cancel(id: CancelID.playback),
            .cancel(id: CancelID.autoPlayCountdown),
            .run { _ in
                await MainActor.run { PlayerManager.shared.stop() }
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
        return .send(.autoPlayCountdownStarted(video, consumesPlayNextQueue: false))
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
            .run { _ in
                // Keep any presented fullscreen player up — the countdown
                // card is surfaced inside it.
                await MainActor.run {
                    PlayerManager.shared.stop(dismissFullscreen: false)
                }
            },
            .run { send in
                // Listen for the countdown card's buttons for the lifetime
                // of this countdown. The card is rendered by the fullscreen
                // player VC, which can't see the store, so it reports taps
                // through `PlayerManager`'s event stream instead.
                let events = await MainActor.run { PlayerManager.shared.events }
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

    private func handleAutoPlayVideo(
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
        let url = mediaURL(state: state)
        let startPosition = state.video.resumePositionSeconds
        let config = state.serverConfig
        let videoId = state.video.videoId
        let currentVideo = video
        let expectedSize = state.video.mediaSize.map { Int64($0) }
        return .merge(
            .run { [videoService] send in
                let events = await VideoDetailReducer.loadAutoPlayStream(
                    url: url,
                    startPosition: startPosition,
                    videoId: videoId,
                    expectedSize: expectedSize,
                    hasPrevious: hasPrevious,
                    currentVideo: currentVideo,
                    config: config
                )
                guard let events else { return }
                let saveTask = VideoDetailReducer.periodicProgressSaveTask(
                    config: config,
                    videoId: videoId,
                    videoService: videoService
                )
                defer { saveTask.cancel() }
                await VideoDetailReducer.consumePlayerEvents(
                    events,
                    videoId: videoId,
                    config: config,
                    videoService: videoService,
                    send: send
                )
            }
            .cancellable(id: CancelID.playback, cancelInFlight: true),
            .send(.view(.viewDidAppear))
        )
    }

    @MainActor
    private static func loadAutoPlayStream(
        url: URL?,
        startPosition: Double?,
        videoId: String,
        expectedSize: Int64?,
        hasPrevious: Bool,
        currentVideo: VideoResponse,
        config: ServerConfig
    ) -> AsyncStream<PlayerEvent>? {
        // Subscribe before stopping the outgoing video, so the `.paused`
        // that `stop()` emits still reaches a listener and the outgoing
        // video's final position is saved. The consumer filters by
        // `videoId`, so that event is correctly ignored by *this* stream's
        // handler while the outgoing video's own effect (not yet cancelled)
        // acts on it.
        let events = PlayerManager.shared.events
        // Auto-advance: keep the fullscreen player up so the next video
        // plays fullscreen without a flash.
        PlayerManager.shared.stop(dismissFullscreen: false)
        PlayerManager.shared.canGoPrevious = hasPrevious
        guard let url else { return nil }
        PlayerManager.shared.load(
            url: url,
            startPosition: startPosition,
            videoId: videoId,
            expectedSize: expectedSize
        )
        PlayerManager.shared.currentVideoID = videoId
        // Refresh now-playing metadata so the title/channel row in the
        // player overlay (and Control Center now-playing) reflect the
        // auto-played video. Without this, the overlay sticks on the
        // previous video's title until the user opens detail manually.
        PlayerManager.shared.currentMetadata = PlayerManager.NowPlayingMetadata(
            title: currentVideo.title,
            artist: currentVideo.channelName,
            duration: Double(currentVideo.player?.duration ?? 0),
            artworkURL: config.thumbnailURL(
                videoId: currentVideo.videoId,
                path: currentVideo.vidThumbUrl
            ),
            channelThumbURL: currentVideo.channel.channelThumbUrl
                .flatMap { config.fullURL(for: $0) },
            authHeaders: config.authHeaders
        )
        return events
    }

    private func handleLoadNextVideo(state: inout State) -> Effect<Action> {
        guard !state.nextVideos.isEmpty else { return .none }
        let nextVideo = state.nextVideos.removeFirst()
        state.resetForNewVideo(nextVideo)
        state.isPlaying = true
        let url = mediaURL(state: state)
        let startPosition = state.video.resumePositionSeconds
        let config = state.serverConfig
        let videoId = state.video.videoId
        let expectedSize = state.video.mediaSize.map { Int64($0) }
        return .merge(
            .run { [videoService] send in
                let events = await MainActor.run { () -> AsyncStream<PlayerEvent>? in
                    // Subscribe before stopping, so the `.paused` emitted
                    // for the outgoing video still reaches its own effect.
                    let events = PlayerManager.shared.events
                    // Loading the next video — keep the fullscreen player
                    // up so playback continues fullscreen seamlessly.
                    PlayerManager.shared.stop(dismissFullscreen: false)
                    guard let url else { return nil }
                    PlayerManager.shared.load(
                        url: url,
                        startPosition: startPosition,
                        videoId: videoId,
                        expectedSize: expectedSize
                    )
                    return events
                }
                guard let events else { return }
                let saveTask = VideoDetailReducer.periodicProgressSaveTask(
                    config: config,
                    videoId: videoId,
                    videoService: videoService
                )
                defer { saveTask.cancel() }
                await VideoDetailReducer.consumePlayerEvents(
                    events,
                    videoId: videoId,
                    config: config,
                    videoService: videoService,
                    send: send
                )
            }
            .cancellable(id: CancelID.playback, cancelInFlight: true),
            .send(.view(.viewDidAppear))
        )
    }
}
