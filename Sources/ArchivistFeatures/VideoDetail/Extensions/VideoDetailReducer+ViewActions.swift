import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoDetailReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .playTapped:
            return handlePlayTapped(state: &state)
        case .stopPlayback:
            return handleStopPlayback(state: &state)
        case .dismissTapped:
            return handleDismissTapped(state: &state)
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
        case .addToPlaylistTapped:
            return handleAddToPlaylistTapped(state: &state)
        case .addToPlayNextTapped:
            return handleAddToPlayNextTapped(state: &state)
        case .removeFromPlayNextTapped(let id):
            return handleRemoveFromPlayNextTapped(id, state: &state)
        case .videoChanged:
            state.showAllComments = false
            state.currentCommentIndex = 0
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = state.video.videoId
        var effects: [Effect<Action>] = []

        state.isDownloaded = localVideoStorage.isDownloaded(videoId: videoId)

        let videoService = self.videoService
        // Fetch latest video data (progress, watched status)
        effects.append(
            .run { send in
                if let video = try? await videoService.getVideo(config: config, id: videoId) {
                    await send(.videoRefreshed(video))
                }
            }
        )

        // Resume observing if a download is already in progress
        effects.append(
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
        )

        if !state.isLoadingComments && state.comments.isEmpty {
            state.isLoadingComments = true
            effects.append(
                .run { [videoService] send in
                    let result = await Result {
                        try await videoService.getComments(config: config, videoId: videoId)
                    }
                    await send(.commentsResult(result))
                }
            )
        }

        if !state.isLoadingSimilar && state.similarVideos.isEmpty {
            state.isLoadingSimilar = true
            effects.append(
                .run { [videoService] send in
                    let result = await Result {
                        try await videoService.getSimilar(config: config, videoId: videoId)
                    }
                    await send(.similarResult(result))
                }
            )
        }

        return .merge(effects)
    }

    private func handlePlayTapped(state: inout State) -> Effect<Action> {
        guard let url = mediaURL(state: state) else { return .none }
        state.isPlaying = true
        let startPosition = state.video.player?.position
        let config = state.serverConfig
        let videoId = state.video.videoId
        let video = state.video
        let authHeaders = state.isDownloaded ? [:] : config.authHeaders
        return .run { [videoService] send in
            let stream = await MainActor.run {
                PlayerManager.shared.configureAuth(
                    videoId: videoId,
                    videoService: videoService,
                    config: config
                )
                PlayerManager.shared.load(
                    url: url,
                    startPosition: startPosition,
                    authHeaders: authHeaders,
                    videoId: videoId
                )
                PlayerManager.shared.onPause = {
                    let position = Int(PlayerManager.shared.currentTime)
                    guard position > 0 else { return }
                    Task.detached {
                        try? await videoService.setProgress(config: config, videoId: videoId, position: position)
                    }
                }
                PlayerManager.shared.currentVideoID = videoId
                PlayerManager.shared.currentMetadata = PlayerManager.NowPlayingMetadata(
                    title: video.title,
                    artist: video.channelName,
                    duration: Double(video.player?.duration ?? 0),
                    artworkURL: config.fullURL(for: video.vidThumbUrl ?? ""),
                    authHeaders: config.authHeaders
                )
                return PlayerManager.shared.playbackEndEvents()
            }
            for await _ in stream {
                await send(.view(.videoPlaybackDidEnd))
            }
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
        let video = state.video
        let nextVideos = state.nextVideos
        let showPlayNext = state.showPlayNext
        let shouldAutoPlay = state.shouldAutoPlayNextVideo

        // Save progress in the background — don't block the dismiss
        let saveEffect: Effect<Action> = .run { [videoService] _ in
            let position = await Int(PlayerManager.shared.currentTime)
            guard position > 0 else { return }
            try? await videoService.setProgress(config: config, videoId: videoId, position: position)
        }

        return .merge(saveEffect, .run { [dismiss] send in
            let isPlaying = await MainActor.run { PlayerManager.shared.isPlaying }
            let isInPiP = await MainActor.run { PlayerManager.shared.isInPiP }

            // Minimize to mini player only if actively playing or in PiP
            if isPlaying || isInPiP {
                await send(.delegate(
                    .didRequestMinimize(
                        video,
                        nextVideos,
                        config,
                        showPlayNext,
                        shouldAutoPlay
                    )
                ))
                return
            }

            // Not playing — stop and dismiss
            await MainActor.run {
                PlayerManager.shared.stop()
            }
            await send(.delegate(.didDismiss(videoId)))
            await dismiss()
        })
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
        let authHeaders = state.serverConfig.authHeaders
        let expectedSize = state.video.mediaSize.map { Int64($0) }
        return .run { [deviceDownloadDatabase, persistentDownloadManager] send in
            let download = DeviceDownload(
                id: videoId,
                title: title,
                channelName: channelName,
                thumbUrl: thumbUrl,
                status: .downloading,
                progress: 0,
                createdAt: Date().timeIntervalSince1970
            )
            try deviceDownloadDatabase.insertDownload(download)

            await persistentDownloadManager.startDownload(
                url: mediaURL, videoId: videoId, title: title, expectedSize: expectedSize, authHeaders: authHeaders
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
            print("[DeviceDownload] insert failed: \(error)")
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
        @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled = true
        guard autoPlayEnabled else {
            state.isPlaying = false
            state.localWatchProgress = 1.0
            state.watchedOverride = true
            return .merge(
                saveEffect,
                .cancel(id: CancelID.playback),
                .run { _ in
                    await MainActor.run { PlayerManager.shared.stop() }
                }
            )
        }
        let config = state.serverConfig
        let currentVideoId = state.video.videoId
        let nextVideos = state.nextVideos
        let shouldAutoPlayNext = state.shouldAutoPlayNextVideo
        let similarVideos = state.similarVideos
        return .merge(saveEffect, .run { [playNextDatabase, videoService] send in
            // 1. Play Next queue (user-curated, highest priority)
            if let nextItem = try? await playNextDatabase.popNext() {
                do {
                    let video = try await videoService.getVideo(config: config, id: nextItem.videoId)
                    await send(.autoPlayVideo(video))
                    return
                } catch {
                    // Video not found, try next source
                }
            }

            // 2. Up Next (contextual queue from video list / playlist)
            if shouldAutoPlayNext, let firstNext = nextVideos.first {
                await send(.autoPlayVideo(firstNext))
                return
            }

            // 3. Similar videos (pre-loaded)
            if let firstSimilar = similarVideos.first {
                await send(.autoPlayVideo(firstSimilar))
                return
            }

            // 4. Fetch similar from server as last resort
            do {
                let similar = try await videoService.getSimilar(config: config, videoId: currentVideoId)
                if let first = similar.first {
                    await send(.autoPlayVideo(first))
                }
            } catch {
                // Nothing to play
            }
        })
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

    private func handleRemoveFromPlayNextTapped(
        _ id: Int,
        state: inout State
    ) -> Effect<Action> {
        return .run { [playNextDatabase] _ in
            try? await playNextDatabase.removeFromQueue(id)
        }
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
}
