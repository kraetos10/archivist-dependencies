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
        case .commentsResult(.success(let comments)):
            state.comments = comments
            state.isLoadingComments = false
            return .none
        case .commentsResult(.failure):
            state.isLoadingComments = false
            return .none
        case .similarResult(.success(let videos)):
            state.similarVideos = videos.filter { !$0.isWatched }
            state.isLoadingSimilar = false
            return .none
        case .similarResult(.failure):
            state.isLoadingSimilar = false
            return .none
        case .downloadResumed(let progress):
            state.isDownloading = true
            state.downloadProgress = progress
            return .none
        case .downloadProgressUpdated(let progress):
            state.downloadProgress = progress
            return .none
        case .downloadCompleted:
            state.isDownloading = false
            state.isDownloaded = true
            state.downloadProgress = 1
            return .none
        case .downloadFailed(let message):
            state.isDownloading = false
            state.downloadError = message
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(message)
            }
            return .none
        case .serverDeleteResult(.success):
            state.isDeletingFromServer = false
            let videoId = state.video.videoId
            try? localVideoStorage.deleteVideo(videoId: videoId)
            try? deviceDownloadDatabase.deleteDownload(videoId)
            state.isDownloaded = false
            return .none
        case .serverDeleteResult(.failure(let error)):
            state.isDeletingFromServer = false
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(error.localizedDescription)
            }
            return .none
        case .watchedToggleResult(.success):
            state.watchedOverride = !(state.watchedOverride ?? state.video.isWatched)
            return .none
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
        case .cacheStatusChanged(let isCached):
            state.isCached = isCached
            return .none
        case .adoptInflightPlayback:
            state.isPlaying = true
            return .none
        case .watchedToggleResult(.failure):
            return .none
        default:
            return .none
        }
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
                // Wire the countdown card's buttons for the lifetime of
                // this countdown so the fullscreen player VC (which can't
                // see the store) can drive play-now / cancel.
                await MainActor.run {
                    PlayerManager.shared.onAutoPlayPlayNow = {
                        Task { @MainActor in
                            await send(.view(.autoPlayCountdownPlayNowTapped))
                        }
                    }
                    PlayerManager.shared.onAutoPlayCancel = {
                        Task { @MainActor in
                            await send(.view(.autoPlayCountdownCancelTapped))
                        }
                    }
                }
                for _ in 0..<Self.autoPlayCountdownSeconds {
                    try? await Task.sleep(for: .seconds(1))
                    await send(.autoPlayCountdownTick)
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
                let stream = await MainActor.run {
                    // Auto-advance: keep the fullscreen player up so the
                    // next video plays fullscreen without a flash.
                    PlayerManager.shared.stop(dismissFullscreen: false)
                    PlayerManager.shared.canGoPrevious = hasPrevious
                    guard let url else { return nil as AsyncStream<Void>? }
                    PlayerManager.shared.load(
                        url: url,
                        startPosition: startPosition,
                        videoId: videoId,
                        expectedSize: expectedSize
                    )
                    PlayerManager.shared.onPause = {
                        let position = Int(PlayerManager.shared.currentTime)
                        guard position > 0 else { return }
                        Task.detached {
                            try? await videoService.setProgress(
                                config: config,
                                videoId: videoId,
                                position: position
                            )
                        }
                    }
                    PlayerManager.shared.onPlaybackCompleted = {
                        // End-of-media notification — fires even when the
                        // detail screen has been dismissed (PiP). Mark the
                        // video watched server-side so the state syncs.
                        Task.detached {
                            try? await videoService.setWatched(
                                config: config,
                                videoId: videoId,
                                isWatched: true
                            )
                        }
                    }
                    PlayerManager.shared.onNextRequested = {
                        Task { @MainActor in
                            await send(.view(.nextVideoRequested))
                        }
                    }
                    PlayerManager.shared.onPreviousRequested = {
                        Task { @MainActor in
                            await send(.view(.previousVideoRequested))
                        }
                    }
                    PlayerManager.shared.currentVideoID = videoId
                    // Refresh now-playing metadata so the title/channel
                    // row in the player overlay (and Control Center
                    // now-playing) reflect the auto-played video.
                    // Without this, the overlay sticks on the previous
                    // video's title until the user opens detail manually.
                    PlayerManager.shared.currentMetadata = PlayerManager.NowPlayingMetadata(
                        title: currentVideo.title,
                        artist: currentVideo.channelName,
                        duration: Double(currentVideo.player?.duration ?? 0),
                        artworkURL: config.fullURL(for: currentVideo.vidThumbUrl ?? ""),
                        channelThumbURL: currentVideo.channel.channelThumbUrl
                            .flatMap { config.fullURL(for: $0) },
                        authHeaders: config.authHeaders
                    )
                    return PlayerManager.shared.playbackEndEvents()
                }
                guard let stream else { return }
                let saveTask = VideoDetailReducer.periodicProgressSaveTask(
                    config: config,
                    videoId: videoId,
                    videoService: videoService
                )
                defer { saveTask.cancel() }
                for await _ in stream {
                    await send(.view(.videoPlaybackDidEnd))
                }
            }
            .cancellable(id: CancelID.playback, cancelInFlight: true),
            .send(.view(.viewDidAppear))
        )
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
                let stream = await MainActor.run {
                    // Loading the next video — keep the fullscreen player
                    // up so playback continues fullscreen seamlessly.
                    PlayerManager.shared.stop(dismissFullscreen: false)
                    guard let url else { return nil as AsyncStream<Void>? }
                    PlayerManager.shared.load(
                        url: url,
                        startPosition: startPosition,
                        videoId: videoId,
                        expectedSize: expectedSize
                    )
                    PlayerManager.shared.onPause = {
                        let position = Int(PlayerManager.shared.currentTime)
                        guard position > 0 else { return }
                        Task.detached {
                            try? await videoService.setProgress(
                                config: config,
                                videoId: videoId,
                                position: position
                            )
                        }
                    }
                    PlayerManager.shared.onPlaybackCompleted = {
                        Task.detached {
                            try? await videoService.setWatched(
                                config: config,
                                videoId: videoId,
                                isWatched: true
                            )
                        }
                    }
                    return PlayerManager.shared.playbackEndEvents()
                }
                guard let stream else { return }
                let saveTask = VideoDetailReducer.periodicProgressSaveTask(
                    config: config,
                    videoId: videoId,
                    videoService: videoService
                )
                defer { saveTask.cancel() }
                for await _ in stream {
                    await send(.view(.videoPlaybackDidEnd))
                }
            }
            .cancellable(id: CancelID.playback, cancelInFlight: true),
            .send(.view(.viewDidAppear))
        )
    }
}
