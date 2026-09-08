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
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .playTapped:
            return handlePlayTappedWarningIfNeeded(state: &state)
        case .stopPlayback:
            return handleStopPlayback(state: &state)
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
        case .videoPlaybackDidEnd:
            return handleVideoPlaybackDidEnd(state: &state)
        case .toggleDescription:
            state.isDescriptionExpanded.toggle()
            return .none
        case .toggleWatchedTapped:
            return handleToggleWatched(state: &state)
        case .nextVideoRequested:
            return .send(.view(.videoPlaybackDidEnd))
        case .previousVideoRequested:
            return handlePreviousVideoRequested(state: &state)
        case .videoChanged:
            state.showAllComments = false
            state.currentCommentIndex = 0
            return .none
        default:
            return .none
        }
    }

    /// The two ways off this screen. Split out of the main switch to keep
    /// its cyclomatic complexity under the project's limit.
    private func handleScreenLifecycleAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action>? {
        switch action {
        case .dismissTapped:
            return handleDismissTapped(state: &state)
        case .minimizeRequested:
            return handleMinimizeRequested(state: &state)
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
        return .merge(
            .cancel(id: CancelID.autoPlayCountdown),
            .send(.autoPlayExhausted)
        )
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
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
        state.isCached = PlaybackCache.isCached(videoId: videoId)

        if !state.isPlaying {
            effects.append(adoptInflightPlaybackEffect(config: config, videoId: videoId))
        }

        effects.append(refreshVideoEffect(config: config, videoId: videoId))
        effects.append(observeDownloadEffect(videoId: videoId))

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
        .run { [videoService] send in
            let events = await MainActor.run { () -> AsyncStream<PlayerEvent>? in
                guard PlayerManager.shared.currentVideoID == videoId,
                      PlayerManager.shared.isPlaying else { return nil }
                return PlayerManager.shared.events
            }
            guard let events else { return }
            await send(.adoptInflightPlayback)
            await VideoDetailReducer.consumePlayerEvents(
                events,
                videoId: videoId,
                config: config,
                videoService: videoService,
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
    }

    private func observeDownloadEffect(videoId: String) -> Effect<Action> {
        .run { [persistentDownloadManager] send in
            let isActive = await persistentDownloadManager.isDownloading(videoId: videoId)
            guard isActive else { return }
            let progress = await persistentDownloadManager.progress(for: videoId)
            await send(.downloadResumed(progress))
            for await event in await persistentDownloadManager.observe(videoId: videoId) {
                switch event {
                case .progress(let progress):
                    await send(.downloadProgressUpdated(progress))
                case .completed:
                    await send(.downloadCompleted)
                case .failed(let msg):
                    await send(.downloadFailed(msg))
                }
            }
        }
    }

    private func fetchCommentsEffect(config: ServerConfig, videoId: String) -> Effect<Action> {
        .run { [videoService] send in
            let result = await Result {
                try await videoService.getComments(config: config, videoId: videoId)
            }
            await send(.commentsResult(result))
        }
    }

    private func fetchSimilarEffect(config: ServerConfig, videoId: String) -> Effect<Action> {
        .run { [videoService] send in
            let result = await Result {
                try await videoService.getSimilar(config: config, videoId: videoId)
            }
            await send(.similarResult(result))
        }
    }

    /// Warns once, on the first 4K VP9/AV1 video the user plays, that the
    /// device has to decode it in software.
    ///
    /// Gated on a persisted flag rather than shown per video: the
    /// limitation belongs to the hardware, so repeating it every time
    /// would just train the user to dismiss it. Playing is still the
    /// default action — the warning informs, it doesn't block.
    private func handlePlayTappedWarningIfNeeded(state: inout State) -> Effect<Action> {
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
        let startPosition = state.video.resumePositionSeconds
        let config = state.serverConfig
        let videoId = state.video.videoId
        let video = state.video
        let expectedSize = state.video.mediaSize.map { Int64($0) }
        return .run { [videoService] send in
            let events = await MainActor.run {
                // Subscribe before loading so nothing emitted during
                // `load()` — an immediate cache hit, say — is missed.
                let events = PlayerManager.shared.events
                PlayerManager.shared.load(
                    url: url,
                    startPosition: startPosition,
                    videoId: videoId,
                    expectedSize: expectedSize
                )
                PlayerManager.shared.currentVideoID = videoId
                PlayerManager.shared.currentMetadata = PlayerManager.NowPlayingMetadata(
                    title: video.title,
                    artist: video.channelName,
                    duration: Double(video.player?.duration ?? 0),
                    artworkURL: config.thumbnailURL(videoId: video.videoId, path: video.vidThumbUrl),
                    channelThumbURL: video.channel.channelThumbUrl
                        .flatMap { config.fullURL(for: $0) },
                    authHeaders: config.authHeaders
                )
                return events
            }
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
        .cancellable(id: CancelID.playback, cancelInFlight: true)
    }

    private func handleStopPlayback(state: inout State) -> Effect<Action> {
        let saveEffect = saveProgressEffect(state: state)
        state.isPlaying = false
        return .merge(
            saveEffect,
            .run { _ in
                await MainActor.run { PlayerManager.shared.stop() }
            }
        )
    }

    private func handleDismissTapped(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId

        // Save progress in the background — don't block the dismiss
        let saveEffect: Effect<Action> = .run { [videoService] _ in
            let position = await Int(PlayerManager.shared.currentTime)
            guard position > 0 else { return }
            try? await videoService.setProgress(config: config, videoId: videoId, position: position)
        }

        let isMiniPlayer = state.isHostedInMiniPlayer

        return .merge(saveEffect, .run { [dismiss] send in
            // Close means close. Dragging the player down is the way to
            // keep it playing, so there's no PiP hand-off here any more.
            await MainActor.run {
                PlayerManager.shared.activePlayerSurfaceRole = .fullDetail
                // This screen owns the countdown mirror and is about to
                // stop existing, so nothing else can clear it.
                PlayerManager.shared.autoPlayCountdown = nil
                PlayerManager.shared.stop()
            }
            await send(.delegate(.didDismiss(videoId)))
            // The mini player's copy of this state isn't presented by
            // anyone — `TabReducer` tears it down off the delegate action
            // above, and calling `dismiss()` here would have nothing to
            // dismiss.
            guard !isMiniPlayer else { return }
            await dismiss()
        })
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
            return .run { send in
                await MainActor.run {
                    PlayerManager.shared.activePlayerSurfaceRole = .mini
                }
                await send(.delegate(.didRequestMinimize))
            }
        }

        let detail = state
        return .run { [dismiss, miniPlayerClient] send in
            await MainActor.run {
                PlayerManager.shared.activePlayerSurfaceRole = .mini
            }
            await miniPlayerClient.request(.minimise(detail))
            await send(.delegate(.didRequestMinimize))
            await dismiss()
        }
    }

    private func saveProgressEffect(state: State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId
        return .run { [videoService] _ in
            let position = await Int(PlayerManager.shared.currentTime)
            guard position > 0 else { return }
            try? await videoService.setProgress(config: config, videoId: videoId, position: position)
        }
    }

    /// Heartbeat that saves playback progress to the server every
    /// `periodicProgressSaveInterval` seconds while playback is active for
    /// `videoId`. Spawned from inside each play-start `.run` so its
    /// lifetime tracks the parent Task — when playback ends (stream
    /// finishes) or the parent effect is cancelled the heartbeat is
    /// cancelled too. Without this the server only learns the position on
    /// pause/dismiss, so a force-quit mid-play loses the run-up.
    ///
    /// Static so the parent `.run` closure (a `@Sendable` block) doesn't
    /// have to capture the non-Sendable reducer struct.
    static func periodicProgressSaveTask(
        config: ServerConfig,
        videoId: String,
        videoService: VideoService
    ) -> Task<Void, Never> {
        Task { [videoService] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(VideoDetailReducer.periodicProgressSaveInterval))
                if Task.isCancelled { break }
                let snapshot = await MainActor.run {
                    (
                        isActive: PlayerManager.shared.isPlaying
                            && PlayerManager.shared.currentVideoID == videoId,
                        position: Int(PlayerManager.shared.currentTime)
                    )
                }
                guard snapshot.isActive, snapshot.position > 0 else { continue }
                try? await videoService.setProgress(
                    config: config,
                    videoId: videoId,
                    position: snapshot.position
                )
            }
        }
    }

    func mediaURL(state: State) -> URL? {
        if state.isDownloaded {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return documents
                .appendingPathComponent("OfflineVideos", isDirectory: true)
                .appendingPathComponent("\(state.video.videoId).mp4")
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
        let channelName = state.video.channelName
        let thumbUrl = state.video.vidThumbUrl
        let thumbnailURL = thumbUrl.flatMap { state.serverConfig.fullURL(for: $0) }
        let authHeaders = state.serverConfig.authHeaders
        let expectedSize = state.video.mediaSize.map { Int64($0) }
        let expectedSizeInt = state.video.mediaSize
        return .run { [deviceDownloadDatabase, persistentDownloadManager] send in
            let download = DeviceDownload(
                id: videoId,
                title: title,
                channelName: channelName,
                thumbUrl: thumbUrl,
                status: .downloading,
                progress: 0,
                fileSize: expectedSizeInt,
                createdAt: Date().timeIntervalSince1970
            )
            try deviceDownloadDatabase.insertDownload(download)

            await persistentDownloadManager.startDownload(
                url: mediaURL,
                videoId: videoId,
                title: title,
                expectedSize: expectedSize,
                authHeaders: authHeaders,
                thumbnailURL: thumbnailURL
            )
            for await event in await persistentDownloadManager.observe(videoId: videoId) {
                switch event {
                case .progress(let progress):
                    await send(.downloadProgressUpdated(progress))
                case .completed:
                    await send(.downloadCompleted)
                case .failed(let msg):
                    await send(.downloadFailed(msg))
                }
            }
        } catch: { error, send in
            await send(.downloadFailed(error.localizedDescription))
        }
    }

    private func handleDeleteDownloadTapped(state: inout State) -> Effect<Action> {
        let videoId = state.video.videoId
        try? localVideoStorage.deleteVideo(videoId: videoId)
        try? deviceDownloadDatabase.deleteDownload(videoId)
        state.isDownloaded = false
        return .none
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
        let videoService = self.videoService
        return .run { send in
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
        let videoService = self.videoService
        return .run { send in
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

    private func handleSimilarVideoTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let saveEffect = saveProgressEffect(state: state)
        state.resetForNewVideo(video)
        state.nextVideos = []
        return .merge(
            saveEffect,
            .run { _ in
                await MainActor.run { PlayerManager.shared.stop() }
            },
            .send(.view(.viewDidAppear))
        )
    }

    private func handleVideoPlaybackDidEnd(state: inout State) -> Effect<Action> {
        let saveEffect = saveProgressEffect(state: state)
        // Nothing auto-advances while collapsed into the mini player.
        // It's a background surface the user isn't watching, so rolling
        // on into another video there would start something they never
        // asked for — `autoPlayExhausted` stops the player, and
        // `TabReducer` takes that as the cue to retire the mini player.
        // Expanded back to full screen it auto-advances as normal.
        guard !state.isMiniPlayerCollapsed else {
            return .merge(saveEffect, .send(.autoPlayExhausted))
        }
        @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled = true
        guard autoPlayEnabled else {
            return .merge(saveEffect, .send(.autoPlayExhausted))
        }
        let config = state.serverConfig
        let currentVideoId = state.video.videoId
        let nextVideos = state.nextVideos
        let shouldAutoPlayNext = state.shouldAutoPlayNextVideo
        let similarVideos = state.similarVideos
        let loopVideoIds = state.loopVideoIds
        return .merge(saveEffect, .run { [playNextDatabase, videoService] send in
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
        })
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
        return .run { [playNextDatabase] _ in
            try? await playNextDatabase.addToQueue(video)
        }
    }

    private func handleRemoveFromPlayNextTapped(
        _ id: Int,
        state: inout State
    ) -> Effect<Action> {
        return .run { [playNextDatabase] _ in
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
        let saveEffect = saveProgressEffect(state: state)
        if let index = state.nextVideos.firstIndex(where: { $0.videoId == video.videoId }) {
            state.nextVideos.removeSubrange(...index)
        }
        state.resetForNewVideo(video)
        return .merge(
            saveEffect,
            .run { _ in
                await MainActor.run { PlayerManager.shared.stop() }
            },
            .send(.view(.viewDidAppear))
        )
    }

    private func handlePreviousVideoRequested(state: inout State) -> Effect<Action> {
        guard let previous = state.previousVideos.popLast() else { return .none }
        return .send(.autoPlayVideo(previous))
    }
}
