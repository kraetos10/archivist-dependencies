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
        case .cacheStatusChanged(let isCached):
            state.isCached = isCached
            return .none
        case .watchedToggleResult(.failure):
            return .none
        default:
            return .none
        }
    }

    private func handleAutoPlayVideo(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
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
        let startPosition = state.video.player?.position
        let config = state.serverConfig
        let videoId = state.video.videoId
        let currentVideo = video
        return .merge(
            .run { [videoService] send in
                let stream = await MainActor.run {
                    PlayerManager.shared.stop()
                    PlayerManager.shared.canGoPrevious = hasPrevious
                    guard let url else { return nil as AsyncStream<Void>? }
                    PlayerManager.shared.load(
                        url: url,
                        startPosition: startPosition,
                        videoId: videoId
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
                    return PlayerManager.shared.playbackEndEvents()
                }
                guard let stream else { return }
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
        let startPosition = state.video.player?.position
        let config = state.serverConfig
        let videoId = state.video.videoId
        return .merge(
            .run { [videoService] send in
                let stream = await MainActor.run {
                    PlayerManager.shared.stop()
                    guard let url else { return nil as AsyncStream<Void>? }
                    PlayerManager.shared.load(
                        url: url,
                        startPosition: startPosition,
                        videoId: videoId
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
                for await _ in stream {
                    await send(.view(.videoPlaybackDidEnd))
                }
            }
            .cancellable(id: CancelID.playback, cancelInFlight: true),
            .send(.view(.viewDidAppear))
        )
    }
}
