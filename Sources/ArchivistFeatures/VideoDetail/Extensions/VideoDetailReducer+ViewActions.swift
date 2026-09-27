import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoDetailReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        if let effect = handlePlayNextQueueAction(action, state: &state) {
            return effect
        }
        if let effect = handleScreenLifecycleAction(action, state: &state) {
            return effect
        }
        if let effect = handleTransportAction(action, state: &state) {
            return effect
        }
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .downloadTapped:
            return handleDownloadTapped(state: &state)
        case .deleteDownloadTapped:
            return handleDeleteDownloadTapped(state: &state)
        case .deleteFromServerTapped:
            return handleDeleteFromServerTapped(state: &state)
        case .similarVideoTapped(let video):
            return handleSimilarVideoTapped(video, state: &state)
        case .nextUpVideoTapped(let video):
            return handleNextUpVideoTapped(video, state: &state)
        case .toggleDescription:
            state.isDescriptionExpanded.toggle()
            return .none
        case .commentsHeaderTapped:
            state.showAllComments.toggle()
            return .none
        case .commentTapped(let comment):
            state.expandedComment = comment
            return .none
        case .toggleWatchedTapped:
            return handleToggleWatched(state: &state)
        default:
            return .none
        }
    }

    /// The ways off this screen. Split out of the main switch to keep its
    /// cyclomatic complexity under the project's limit.
    private func handleScreenLifecycleAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action>? {
        switch action {
        case .dismissTapped:
            return handleDismissTapped(state: &state)
        case .channelTapped:
            return handleChannelTapped(state: &state)
        case .minimizeRequested:
            return handleMinimizeRequested(state: &state)
        case .playerPresentationChanged(let isPresented):
            return handlePlayerPresentationChanged(isPresented, state: &state)
        default:
            return nil
        }
    }

    /// Starting, stopping and stepping through playback.
    private func handleTransportAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action>? {
        switch action {
        case .playTapped:
            return handlePlayTappedResumeChoiceIfNeeded(state: &state)
        case .stopPlayback:
            return handleStopPlayback(state: &state)
        case .videoPlaybackDidEnd, .nextVideoRequested:
            return handleVideoPlaybackDidEnd(state: &state)
        case .previousVideoRequested:
            return handlePreviousVideoRequested(state: &state)
        case .childPlayPauseTapped:
            return .run { [playerClient] _ in
                await playerClient.togglePlayPause()
            }
        case .childSeekRequested(let fraction):
            let clamped = min(max(fraction, 0), 1)
            return .run { [playerClient] _ in
                let duration = await playerClient.duration()
                guard duration > 0 else { return }
                await playerClient.seek(to: clamped * duration)
            }
        default:
            return nil
        }
    }

    private func handlePlayNextQueueAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action>? {
        switch action {
        case .addToPlaylistTapped:
            return handleAddToPlaylistTapped(state: &state)
        case .addToPlayNextTapped:
            return handleAddToPlayNextTapped(state: &state)
        case .addUpNextToPlayNextTapped(let video):
            return handleAddUpNextToPlayNextTapped(video, state: &state)
        case .removeFromPlayNextTapped(let id):
            return handleRemoveFromPlayNextTapped(id, state: &state)
        case .playNextItemTapped(let item):
            return handlePlayNextItemTapped(item, state: &state)
        case .autoPlayCountdownPlayNowTapped:
            return handleAutoPlayCountdownPlayNow(state: &state)
        case .autoPlayCountdownCancelTapped:
            return handleAutoPlayCountdownCancel(state: &state)
        default:
            return nil
        }
    }

    func handleAutoPlayCountdownPlayNow(state: inout State) -> Effect<Action> {
        guard let countdown = state.autoPlayCountdown else { return .none }
        let next = countdown.nextVideo
        let consumes = countdown.consumesPlayNextQueue
        state.autoPlayCountdown = nil
        return .merge(
            .cancel(id: CancelID.autoPlayCountdown),
            .run { [playNextDatabase] send in
                if consumes {
                    _ = try? await playNextDatabase.popNext()
                }
                await send(.autoPlayVideo(next))
            }
        )
    }

    func handleAutoPlayCountdownCancel(state: inout State) -> Effect<Action> {
        state.autoPlayCountdown = nil
        // `autoPlayExhausted` is sent rather than handled inline: it is
        // also `TabReducer`'s cue to retire the mini player.
        return .merge(
            .cancel(id: CancelID.autoPlayCountdown),
            .send(.autoPlayExhausted)
        )
    }

    // MARK: - Private Handlers

    /// Loads everything the screen shows for `state.video`.
    ///
    /// Also the second half of every in-place video switch (similar, next
    /// up, auto-advance): each load restarts under its own cancel ID with
    /// `cancelInFlight`, which is what stops the previous video's responses
    /// and download events from landing on the new one.
    func handleViewDidAppear(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId
        var effects: [Effect<Action>] = []

        // A detail screen and the mini player can't both host the player,
        // so opening one retires the other. The mini player's own expanded
        // screen is the exception — it *is* the mini player.
        if !state.isHostedInMiniPlayer {
            effects.append(
                .run { [miniPlayerClient] _ in
                    await miniPlayerClient.request(.detailAppeared(videoId: videoId))
                }
            )
        }

        state.isDownloaded = localVideoStorage.isDownloaded(videoId: videoId)
        state.isCached = offlineMedia.isCached(videoId)

        if !state.isPlaying {
            effects.append(adoptInflightPlaybackEffect(config: config, videoId: videoId))
        }

        effects.append(refreshVideoEffect(config: config, videoId: videoId))

        // A download started from this screen already has its observer.
        if !state.isDownloading {
            effects.append(observeDownloadEffect(videoId: videoId))
        }

        if !state.isLoadingComments && state.comments.isEmpty {
            state.isLoadingComments = true
            effects.append(fetchCommentsEffect(config: config, videoId: videoId))
        }

        if !state.isLoadingSimilar && state.similarVideos.isEmpty {
            state.isLoadingSimilar = true
            effects.append(fetchSimilarEffect(config: config, videoId: videoId))
        }

        return .merge(effects)
    }

    /// Adopt in-flight playback if the player is already streaming this
    /// video — typically a PiP restore where the user closed the detail
    /// screen, watched in PiP, then tapped restore. Re-mounts the player
    /// surface and re-subscribes to player events without calling `load`
    /// (which would `stop()` and visibly restart playback).
    func adoptInflightPlaybackEffect(config: ServerConfig, videoId: String) -> Effect<Action> {
        .run { [playerClient, videoService] send in
            guard let events = await playerClient.eventsIfPlaying(videoId) else { return }
            await send(.adoptInflightPlayback)
            await VideoDetailReducer.observePlayback(
                events,
                videoId: videoId,
                config: config,
                videoService: videoService,
                playerClient: playerClient,
                send: send
            )
        }
        .cancellable(id: CancelID.playback, cancelInFlight: true)
    }

    private func refreshVideoEffect(config: ServerConfig, videoId: String) -> Effect<Action> {
        .run { [videoService] send in
            if let video = try? await videoService.getVideo(config: config, id: videoId) {
                await send(.videoRefreshed(video))
            }
        }
        .cancellable(id: CancelID.refresh, cancelInFlight: true)
    }

    private func observeDownloadEffect(videoId: String) -> Effect<Action> {
        .run { [persistentDownloadManager] send in
            let isActive = await persistentDownloadManager.isDownloading(videoId: videoId)
            guard isActive else { return }
            let progress = await persistentDownloadManager.progress(for: videoId)
            await send(.downloadResumed(videoId: videoId, progress: progress))
            let events = await persistentDownloadManager.observe(videoId: videoId)
            await Self.forwardDownloadEvents(
                events,
                videoId: videoId,
                send: send
            )
        }
        .cancellable(id: CancelID.downloadObservation, cancelInFlight: true)
    }

    private static func forwardDownloadEvents(
        _ events: AsyncStream<DownloadEvent>,
        videoId: String,
        send: Send<Action>
    ) async {
        for await event in events {
            switch event {
            case .progress(let progress):
                await send(.downloadProgressUpdated(videoId: videoId, progress: progress))
            case .completed:
                await send(.downloadCompleted(videoId: videoId))
            case .failed(let message):
                await send(.downloadFailed(videoId: videoId, message: message))
            }
        }
    }

    private func fetchCommentsEffect(config: ServerConfig, videoId: String) -> Effect<Action> {
        .run { [videoService] send in
            let result = await Result {
                try await videoService.getComments(config: config, videoId: videoId)
            }
            await send(.commentsResult(videoId: videoId, result))
        }
        .cancellable(id: CancelID.comments, cancelInFlight: true)
    }

    private func fetchSimilarEffect(config: ServerConfig, videoId: String) -> Effect<Action> {
        .run { [videoService] send in
            let result = await Result {
                try await videoService.getSimilar(config: config, videoId: videoId)
            }
            await send(.similarResult(videoId: videoId, result))
        }
        .cancellable(id: CancelID.similar, cancelInFlight: true)
    }

    /// Asks whether to resume or start over, on tvOS only.
    ///
    /// The Apple TV convention for a partly-watched video: the button just
    /// says Play, and the choice is made here. Everywhere else the button
    /// itself says Resume, so tapping it has already answered the question.
    ///
    /// `handlePlayTappedWarningIfNeeded` runs either way, so the
    /// software-decode warning still gets its say after this one.
    private func handlePlayTappedResumeChoiceIfNeeded(state: inout State) -> Effect<Action> {
        #if os(tvOS)
        guard let resumePosition = state.video.resumePositionSeconds,
              resumePosition > 0
        else { return handlePlayTappedWarningIfNeeded(state: &state) }

        state.alert = AlertState {
            TextState(String.localised("video.resumePrompt.title", table: .videos))
        } actions: {
            ButtonState(action: .resumeFromPosition) {
                TextState(String.localised("video.resume", table: .videos))
            }
            ButtonState(action: .playFromBeginning) {
                TextState(String.localised("video.startFromBeginning", table: .videos))
            }
            ButtonState(role: .cancel, action: .dismissed) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
        } message: {
            TextState(String.localised("video.resumePrompt.message", table: .videos))
        }
        return .none
        #else
        return handlePlayTappedWarningIfNeeded(state: &state)
        #endif
    }

    /// Warns once, on the first 4K VP9/AV1 video the user plays, that the
    /// device has to decode it in software.
    ///
    /// Gated on a persisted flag rather than shown per video: the
    /// limitation belongs to the hardware, so repeating it every time
    /// would just train the user to dismiss it. Playing is still the
    /// default action — the warning informs, it doesn't block.
    func handlePlayTappedWarningIfNeeded(state: inout State) -> Effect<Action> {
        guard state.video.requiresSoftwareDecodingAtHighResolution,
              !state.hasSeenSoftwareDecodeWarning
        else { return handlePlayTapped(state: &state) }

        state.$hasSeenSoftwareDecodeWarning.withLock { $0 = true }
        state.alert = AlertState {
            TextState(String.localised("video.softwareDecode.title", table: .videos))
        } actions: {
            ButtonState(action: .confirmSoftwareDecodePlayback) {
                TextState(String.localised("video.softwareDecode.continue", table: .videos))
            }
            ButtonState(role: .cancel, action: .dismissed) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
        } message: {
            TextState(String.localised("video.softwareDecode.message", table: .videos))
        }
        return .none
    }

    func handlePlayTapped(state: inout State) -> Effect<Action> {
        guard let url = mediaURL(state: state) else { return .none }
        state.isPlaying = true
        let startPosition = state.playbackStartsAtBeginning
            ? nil
            : state.video.resumePositionSeconds
        state.playbackStartsAtBeginning = false
        let config = state.serverConfig
        let videoId = state.video.videoId
        let request = PlayerClient.PlaybackRequest(
            url: url,
            startPosition: startPosition,
            videoId: videoId,
            expectedSize: state.video.mediaSize.map { Int64($0) },
            metadata: Self.nowPlayingMetadata(for: state.video, config: config)
        )
        return .run { [playerClient, videoService] send in
            // Subscribes before loading, in one main-actor turn, so nothing
            // emitted during `load()` — an immediate cache hit, say — is
            // missed.
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
        .cancellable(id: CancelID.playback, cancelInFlight: true)
    }

    /// Now-playing metadata for the overlay title row and Control Center.
    static func nowPlayingMetadata(
        for video: VideoResponse,
        config: ServerConfig
    ) -> PlayerManager.NowPlayingMetadata {
        PlayerManager.NowPlayingMetadata(
            title: video.title,
            artist: video.channelName,
            duration: Double(video.player?.duration ?? 0),
            artworkURL: config.thumbnailURL(videoId: video.videoId, path: video.vidThumbUrl),
            channelThumbURL: video.channel.channelThumbUrl
                .flatMap { config.fullURL(for: $0) },
            authHeaders: config.authHeaders
        )
    }

    private func handleStopPlayback(state: inout State) -> Effect<Action> {
        state.isPlaying = false
        return stopAndSaveProgressEffect(state: state, dismissFullscreen: true)
    }

    /// The tvOS player is a full-screen cover bound to `isPlaying`. The
    /// cover going away (Menu in the player) is the user stopping playback.
    private func handlePlayerPresentationChanged(
        _ isPresented: Bool,
        state: inout State
    ) -> Effect<Action> {
        guard !isPresented, state.isPlaying else { return .none }
        return handleStopPlayback(state: &state)
    }

    private func handleDismissTapped(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId
        let isMiniPlayer = state.isHostedInMiniPlayer

        return .run { [dismiss, playerClient, videoService] send in
            // Close means close. Dragging the player down is the way to
            // keep it playing, so there's no PiP hand-off here any more.
            let position = await MainActor.run {
                playerClient.setActivePlayerSurfaceRole(.fullDetail)
                // This screen owns the countdown mirror and is about to
                // stop existing, so nothing else can clear it.
                playerClient.setAutoPlayCountdown(nil)
                // Read and stop in one turn: `stop()` zeroes the position.
                return playerClient.stopReturningPosition(dismissFullscreen: true)
            }
            // Detached, so dismissing never waits on the network and the
            // write outlives this effect, which dies with the screen.
            if position > 0 {
                VideoDetailReducer.saveProgressDetached(
                    config: config,
                    videoId: videoId,
                    position: Int(position),
                    videoService: videoService
                )
            }
            await send(.delegate(.didDismiss(videoId)))
            // The mini player's copy of this state isn't presented by
            // anyone — `TabReducer` tears it down off the delegate action
            // above, and calling `dismiss()` here would have nothing to
            // dismiss.
            guard !isMiniPlayer else { return }
            await dismiss()
        }
    }

    /// Hands this screen's state to `TabReducer` so playback can carry on
    /// in the floating mini player, then dismisses the screen.
    ///
    /// The surface role is switched *before* the request so the mini
    /// player's host adopts the live VLC view as soon as it mounts. The
    /// dismissed screen's host only detaches a surface it still owns, so
    /// ordering it this way avoids the orphaned-view window that makes VLC
    /// stall its video output.
    private func handleMinimizeRequested(state: inout State) -> Effect<Action> {
        // Nothing to carry over if nothing is playing — the drag should
        // spring back instead.
        guard state.isPlaying else { return .none }

        // Already the tab's mini-player state, only expanded: the tab owns
        // it, so re-minimising is just a surface + visibility change.
        guard !state.isHostedInMiniPlayer else {
            return .run { [playerClient] send in
                await playerClient.setActivePlayerSurfaceRole(.mini)
                await send(.delegate(.didRequestMinimize))
            }
        }

        let detail = state
        return .run { [dismiss, miniPlayerClient, playerClient] send in
            await playerClient.setActivePlayerSurfaceRole(.mini)
            await miniPlayerClient.request(.minimise(detail))
            await send(.delegate(.didRequestMinimize))
            await dismiss()
        }
    }

    /// Opens the video's channel in the Channels tab. A playing video moves
    /// to the mini player and keeps going, the way a drag down would; one
    /// that isn't playing closes like the X. Either way this screen is
    /// gone, since the channel opens in a tab behind it.
    private func handleChannelTapped(state: inout State) -> Effect<Action> {
        #if os(iOS)
        let channel = ChannelResponse(videoChannel: state.video.channel)

        // Already the tab's mini-player state, only expanded: collapse it
        // back to the floating player, then open the channel.
        if state.isHostedInMiniPlayer {
            return .run { [miniPlayerClient, playerClient] send in
                await playerClient.setActivePlayerSurfaceRole(.mini)
                await send(.delegate(.didRequestMinimize))
                await miniPlayerClient.request(.showChannel(channel, minimising: nil))
            }
        }

        guard state.isPlaying else {
            return .merge(
                handleDismissTapped(state: &state),
                .run { [miniPlayerClient] _ in
                    await miniPlayerClient.request(.showChannel(channel, minimising: nil))
                }
            )
        }

        // As `handleMinimizeRequested`: the surface role switches before
        // the request so the mini player adopts the live surface on mount.
        let detail = state
        return .run { [dismiss, miniPlayerClient, playerClient] send in
            await playerClient.setActivePlayerSurfaceRole(.mini)
            await miniPlayerClient.request(.showChannel(channel, minimising: detail))
            await send(.delegate(.didRequestMinimize))
            await dismiss()
        }
        #else
        // tvOS has no mini player and no channel link on this screen.
        return .none
        #endif
    }

    /// Saves the current position without stopping — for paths where the
    /// next video's load does the stopping.
    func saveProgressEffect(state: State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId
        return .run { [playerClient, videoService] _ in
            let position = await Int(playerClient.currentTime())
            guard position > 0 else { return }
            try? await videoService.setProgress(config: config, videoId: videoId, position: position)
        }
    }

    /// Stops playback and saves where it stopped. The position is read in
    /// the same main-actor turn as the stop — reading it in a sibling
    /// effect raced `stop()`, which zeroes it, and could save nothing.
    func stopAndSaveProgressEffect(
        state: State,
        dismissFullscreen: Bool
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId
        return .run { [playerClient, videoService] _ in
            let position = await Int(
                playerClient.stopReturningPosition(dismissFullscreen: dismissFullscreen)
            )
            guard position > 0 else { return }
            try? await videoService.setProgress(config: config, videoId: videoId, position: position)
        }
    }

    /// Heartbeat that saves playback progress to the server every
    /// `periodicProgressSaveInterval` seconds while playback is active for
    /// `videoId`. Runs as a child task of `observePlayback`, so it ends with
    /// the playback effect. Without it the server only learns the position
    /// on pause/dismiss, so a force-quit mid-play loses the run-up.
    static func periodicProgressSave(
        config: ServerConfig,
        videoId: String,
        videoService: VideoService,
        playerClient: PlayerClient
    ) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(VideoDetailReducer.periodicProgressSaveInterval))
            if Task.isCancelled { break }
            let snapshot = await playerClient.snapshot()
            let position = Int(snapshot.currentTime)
            guard snapshot.isPlaying,
                  snapshot.videoId == videoId,
                  position > 0
            else { continue }
            try? await videoService.setProgress(
                config: config,
                videoId: videoId,
                position: position
            )
        }
    }

    /// Consumes player events for `videoId` alongside the periodic progress
    /// save, as structured child tasks: when the event stream ends or the
    /// playback effect is cancelled, the heartbeat goes with it.
    static func observePlayback(
        _ events: AsyncStream<PlayerEvent>,
        videoId: String,
        config: ServerConfig,
        videoService: VideoService,
        playerClient: PlayerClient,
        send: Send<Action>
    ) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await VideoDetailReducer.periodicProgressSave(
                    config: config,
                    videoId: videoId,
                    videoService: videoService,
                    playerClient: playerClient
                )
            }
            await VideoDetailReducer.consumePlayerEvents(
                events,
                videoId: videoId,
                config: config,
                videoService: videoService,
                send: send
            )
            group.cancelAll()
        }
    }

    func mediaURL(state: State) -> URL? {
        if state.isDownloaded {
            return offlineMedia.localFileURL(state.video.videoId)
        }
        guard let mediaPath = state.video.mediaUrl else { return nil }
        return state.serverConfig.fullURL(for: mediaPath)
    }

    private func handleDownloadTapped(state: inout State) -> Effect<Action> {
        guard !state.isDownloading,
              let mediaPath = state.video.mediaUrl,
              let mediaURL = state.serverConfig.fullURL(for: mediaPath) else {
            return .none
        }
        state.isDownloading = true
        state.downloadProgress = 0
        state.downloadError = nil
        let videoId = state.video.videoId
        let title = state.video.title
        let thumbUrl = state.video.vidThumbUrl
        let download = DeviceDownload(
            id: videoId,
            title: title,
            channelName: state.video.channelName,
            thumbUrl: thumbUrl,
            status: .downloading,
            progress: 0,
            fileSize: state.video.mediaSize,
            createdAt: now.timeIntervalSince1970
        )
        let thumbnailURL = thumbUrl.flatMap { state.serverConfig.fullURL(for: $0) }
        let authHeaders = state.serverConfig.authHeaders
        let expectedSize = state.video.mediaSize.map { Int64($0) }
        return .run { [deviceDownloadDatabase, persistentDownloadManager] send in
            try deviceDownloadDatabase.insertDownload(download)

            await persistentDownloadManager.startDownload(
                url: mediaURL,
                videoId: videoId,
                title: title,
                expectedSize: expectedSize,
                authHeaders: authHeaders,
                thumbnailURL: thumbnailURL
            )
            let events = await persistentDownloadManager.observe(videoId: videoId)
            await Self.forwardDownloadEvents(
                events,
                videoId: videoId,
                send: send
            )
        } catch: { error, send in
            await send(.downloadFailed(videoId: videoId, message: error.localizedDescription))
        }
        .cancellable(id: CancelID.downloadObservation, cancelInFlight: true)
    }

    private func handleDeleteDownloadTapped(state: inout State) -> Effect<Action> {
        state.isDownloaded = false
        return deleteLocalCopyEffect(videoId: state.video.videoId)
    }

    /// Removes the offline file and its database row, off the reducer.
    func deleteLocalCopyEffect(videoId: String) -> Effect<Action> {
        .run { [localVideoStorage, deviceDownloadDatabase] _ in
            try? localVideoStorage.deleteVideo(videoId: videoId)
            try? deviceDownloadDatabase.deleteDownload(videoId)
        }
    }

    private func handleDeleteFromServerTapped(state: inout State) -> Effect<Action> {
        guard !state.isDeletingFromServer else { return .none }
        let message = state.isDownloaded
            ? String.localised("video.confirmDeleteFromServerWithLocal", table: .videos)
            : String.localised("video.confirmDeleteFromServer", table: .videos)
        state.alert = AlertState {
            TextState(String.localised("video.deleteFromServer", table: .videos))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeleteFromServer) {
                TextState(String.localised("generic.delete", table: .generic))
            }
            ButtonState(role: .cancel, action: .dismissed) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
        } message: {
            TextState(message)
        }
        return .none
    }

    func handleConfirmedDeleteFromServer(state: inout State) -> Effect<Action> {
        state.isDeletingFromServer = true
        let config = state.serverConfig
        let videoId = state.video.videoId
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.deleteVideo(config: config, id: videoId)
            }
            await send(.serverDeleteResult(result))
        }
    }

    private func handleToggleWatched(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId
        let newWatched = !state.isWatched
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.setWatched(config: config, videoId: videoId, isWatched: newWatched)
                // Marking watched resets stored playtime so the video
                // starts from the beginning next time.
                if newWatched {
                    try await videoService.deleteProgress(config: config, videoId: videoId)
                }
            }
            await send(.watchedToggleResult(result))
        }
    }

    /// Swaps this screen to `video` in place and starts loading it.
    ///
    /// Stops the outgoing video (saving where it got to), drops any pending
    /// countdown or next-video lookup, then runs the appear logic — whose
    /// loads restart with `cancelInFlight`, cancelling the old video's.
    private func switchToVideo(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let stopEffect = stopAndSaveProgressEffect(state: state, dismissFullscreen: true)
        state.resetForNewVideo(video)
        return .merge(
            .cancel(id: CancelID.autoPlayCountdown),
            .cancel(id: CancelID.autoPlayResolve),
            stopEffect,
            handleViewDidAppear(state: &state)
        )
    }

    private func handleSimilarVideoTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        state.nextVideos = []
        return switchToVideo(video, state: &state)
    }

    private func handleVideoPlaybackDidEnd(state: inout State) -> Effect<Action> {
        let saveEffect = saveProgressEffect(state: state)
        // Nothing auto-advances while collapsed into the mini player.
        // It's a background surface the user isn't watching, so rolling
        // on into another video there would start something they never
        // asked for — `autoPlayExhausted` stops the player, and
        // `TabReducer` takes that as the cue to retire the mini player
        // (which is why it's sent, not handled inline).
        // Expanded back to full screen it auto-advances as normal.
        guard !state.isMiniPlayerCollapsed else {
            return .merge(saveEffect, .send(.autoPlayExhausted))
        }
        @Shared(.autoPlayEnabled) var autoPlayEnabled
        guard autoPlayEnabled else {
            return .merge(saveEffect, .send(.autoPlayExhausted))
        }
        let config = state.serverConfig
        let currentVideoId = state.video.videoId
        let nextVideos = state.nextVideos
        let shouldAutoPlayNext = state.shouldAutoPlayNextVideo
        let similarVideos = state.similarVideos
        let loopVideoIds = state.loopVideoIds
        let resolveEffect: Effect<Action> = .run { [playNextDatabase, videoService] send in
            // 1. Play Next queue (user-curated, highest priority)
            // Peek (don't pop) so the row stays queued if the user
            // cancels the countdown — we only consume it when the
            // autoplay actually fires.
            if let nextItem = try? await playNextDatabase.peekNext() {
                do {
                    let video = try await videoService.getVideo(config: config, id: nextItem.videoId)
                    await send(.autoPlayCountdownStarted(video, consumesPlayNextQueue: true))
                    return
                } catch {
                    // Video not found, try next source
                }
            }

            // 2. Up Next (contextual queue from video list / playlist)
            if shouldAutoPlayNext, let firstNext = nextVideos.first {
                await send(.autoPlayCountdownStarted(firstNext, consumesPlayNextQueue: false))
                return
            }

            // 2b. Looping playlist — walk on from the current entry,
            // wrapping past the last one back to the first. Turning loop on
            // is an explicit, per-playlist choice, so it advances even when
            // the general "autoplay playlist" preference is off.
            if !loopVideoIds.isEmpty {
                let upcomingIds = Self.loopIds(after: currentVideoId, in: loopVideoIds)
                let upcoming = await Self.fetchVideos(
                    ids: upcomingIds,
                    config: config,
                    videoService: videoService
                )
                if let first = upcoming.first {
                    await send(.playlistLoopAdvanced(first, nextVideos: Array(upcoming.dropFirst())))
                    return
                }
            }

            // 3. Similar videos (pre-loaded)
            if let firstSimilar = similarVideos.first {
                await send(.autoPlayCountdownStarted(firstSimilar, consumesPlayNextQueue: false))
                return
            }

            // 4. Fetch similar from server as last resort
            if let similar = try? await videoService.getSimilar(config: config, videoId: currentVideoId),
               let first = similar.first {
                await send(.autoPlayCountdownStarted(first, consumesPlayNextQueue: false))
                return
            }

            // No source had a follow-up — drop back to the thumbnail.
            await send(.autoPlayExhausted)
        }
        return .merge(
            saveEffect,
            resolveEffect.cancellable(id: CancelID.autoPlayResolve, cancelInFlight: true)
        )
    }

    /// Playlist IDs following `videoId`, wrapped around the end of the
    /// playlist. A single-entry playlist yields that same entry, so looping
    /// it replays the one video.
    static func loopIds(
        after videoId: String,
        in ids: [String],
        limit: Int = 11
    ) -> [String] {
        guard let index = ids.firstIndex(of: videoId) else {
            return Array(ids.prefix(limit))
        }
        let rotated = Array(ids[ids.index(after: index)...]) + Array(ids[...index])
        return Array(rotated.prefix(limit))
    }

    /// Resolves IDs to videos concurrently while preserving playlist order.
    /// Entries the server can no longer serve are dropped rather than
    /// stalling the loop.
    static func fetchVideos(
        ids: [String],
        config: ServerConfig,
        videoService: VideoService
    ) async -> [VideoResponse] {
        await withTaskGroup(of: (Int, VideoResponse)?.self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask {
                    guard let video = try? await videoService.getVideo(config: config, id: id) else {
                        return nil
                    }
                    return (index, video)
                }
            }
            var results: [(Int, VideoResponse)] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func handleAddToPlaylistTapped(state: inout State) -> Effect<Action> {
        state.playlistPicker = PlaylistPickerReducer.State(
            serverConfig: state.serverConfig,
            videoId: state.video.videoId
        )
        return .none
    }

    private func handleAddToPlayNextTapped(state: inout State) -> Effect<Action> {
        let video = state.video
        return .run { [playNextDatabase] _ in
            try? await playNextDatabase.addToQueue(video)
        }
    }

    private func handleAddUpNextToPlayNextTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        .run { [playNextDatabase] _ in
            try? await playNextDatabase.addToQueue(video)
        }
    }

    private func handleRemoveFromPlayNextTapped(
        _ id: Int,
        state: inout State
    ) -> Effect<Action> {
        .run { [playNextDatabase] _ in
            try? await playNextDatabase.removeFromQueue(id)
        }
    }

    private func handlePlayNextItemTapped(
        _ item: PlayNextItem,
        state: inout State
    ) -> Effect<Action> {
        let saveEffect = saveProgressEffect(state: state)
        let config = state.serverConfig
        return .merge(
            saveEffect,
            .cancel(id: CancelID.autoPlayResolve),
            .run { [videoService, playNextDatabase] send in
                try? await playNextDatabase.removeFromQueue(item.id)
                guard let video = try? await videoService.getVideo(
                    config: config,
                    id: item.videoId
                ) else { return }
                await send(.autoPlayVideo(video))
            }
        )
    }

    private func handleNextUpVideoTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        if let index = state.nextVideos.firstIndex(where: { $0.videoId == video.videoId }) {
            state.nextVideos.removeSubrange(...index)
        }
        return switchToVideo(video, state: &state)
    }

    private func handlePreviousVideoRequested(state: inout State) -> Effect<Action> {
        guard let previous = state.previousVideos.popLast() else { return .none }
        return handleAutoPlayVideo(previous, state: &state)
    }
}
