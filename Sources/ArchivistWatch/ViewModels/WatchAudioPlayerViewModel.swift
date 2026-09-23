#if os(watchOS)
import AVFoundation
import ArchivistNetworking
import Foundation
import MediaPlayer

/// Registrations that have to be undone when a player goes away: the periodic
/// time observer and the handlers this player put on the *shared* remote
/// command centre. `deinit` is nonisolated and so cannot reach `@MainActor`
/// state — these closures can be run from it, and are released with the box if
/// `teardown()` never ran.
private final class WatchPlayerTeardownHandles: @unchecked Sendable {
    private var releases: [() -> Void] = []

    func add(_ release: @escaping () -> Void) {
        releases.append(release)
    }

    func releaseAll() {
        let pending = releases
        releases = []
        pending.forEach { $0() }
    }

    deinit {
        releaseAll()
    }
}

@MainActor
@Observable
public final class WatchAudioPlayerViewModel {
    public var title: String
    public var channelName: String
    public var thumbPath: String?
    public var isPlaying = false
    public var isLoading = true
    public var isDownloading = false
    public var isDownloaded = false
    public var deleteRequested = false
    public var progress: Double = 0
    public var elapsed: TimeInterval = 0
    public var duration: TimeInterval = 0

    public var downloadProgress: Double {
        WatchDownloadManager.shared.progress
    }

    public let videoId: String
    private var mediaUrl: String?
    public let serverConfig: ServerConfig
    private var avPlayer: AVPlayer?
    private var localPlayer: AVAudioPlayer?
    private var progressTask: Task<Void, Never>?
    private var lastPersistedPosition: TimeInterval = 0
    private let teardownHandles = WatchPlayerTeardownHandles()
    private let videoService: VideoService
    public let isStreaming: Bool

    public var elapsedFormatted: String {
        formatTime(elapsed)
    }

    public var remainingFormatted: String {
        let remaining = max(duration - elapsed, 0)
        return "-\(formatTime(remaining))"
    }

    // MARK: - Streaming init

    public init(
        video: VideoResponse,
        serverConfig: ServerConfig,
        videoService: VideoService = .liveValue
    ) {
        self.videoId = video.videoId
        self.title = video.title
        self.channelName = video.channelName
        self.thumbPath = video.vidThumbUrl
        self.mediaUrl = video.mediaUrl
        self.serverConfig = serverConfig
        self.videoService = videoService
        self.isStreaming = true
        self.isDownloaded = WatchAudioStorage().isDownloaded(videoId: video.videoId)

        configureAudioSession()
        configureRemoteCommands()

        Task {
            await setupStreaming(video: video)
        }
    }

    // MARK: - Local file init

    public init(
        videoId: String,
        title: String,
        channelName: String,
        thumbPath: String?,
        fileURL: URL,
        serverConfig: ServerConfig,
        videoService: VideoService = .liveValue,
        startPosition: TimeInterval = 0
    ) {
        self.videoId = videoId
        self.title = title
        self.channelName = channelName
        self.thumbPath = thumbPath
        self.serverConfig = serverConfig
        self.videoService = videoService
        self.isStreaming = false

        configureAudioSession()
        setupLocalPlayer(fileURL: fileURL, startPosition: startPosition)
        configureNowPlaying()
        configureRemoteCommands()
    }

    public func togglePlayPause() {
        if isStreaming {
            guard let avPlayer else { return }
            if isPlaying {
                avPlayer.pause()
                isPlaying = false
                syncProgressToServer()
            } else {
                avPlayer.play()
                isPlaying = true
                WatchNowPlayingState.shared.setPlayer(self)
            }
        } else {
            guard let localPlayer else { return }
            if localPlayer.isPlaying {
                localPlayer.pause()
                isPlaying = false
                stopProgressUpdates()
                syncProgressToServer()
            } else {
                localPlayer.play()
                isPlaying = true
                startProgressUpdates()
                WatchNowPlayingState.shared.setPlayer(self)
            }
        }
        updateNowPlayingPlaybackState()
    }

    public func skipForward() {
        if isStreaming {
            guard let avPlayer else { return }
            let target = CMTimeGetSeconds(avPlayer.currentTime()) + 30
            avPlayer.seek(to: CMTime(seconds: min(target, duration), preferredTimescale: 1))
        } else {
            guard let localPlayer else { return }
            localPlayer.currentTime = min(localPlayer.currentTime + 30, localPlayer.duration)
            updateLocalProgress()
        }
    }

    public func skipBackward() {
        if isStreaming {
            guard let avPlayer else { return }
            let target = CMTimeGetSeconds(avPlayer.currentTime()) - 15
            avPlayer.seek(to: CMTime(seconds: max(target, 0), preferredTimescale: 1))
        } else {
            guard let localPlayer else { return }
            localPlayer.currentTime = max(localPlayer.currentTime - 15, 0)
            updateLocalProgress()
        }
    }

    public func syncProgressToServer() {
        guard duration > 0 else { return }
        persistLocalPosition()
        Task {
            try? await videoService.setProgress(
                config: serverConfig,
                videoId: videoId,
                position: Int(elapsed)
            )
        }
    }

    /// Leaving the screen doesn't end the session — playback carries on and the
    /// Now Playing tab keeps showing it. A player that was never started has
    /// nothing keeping it alive, so it releases its registrations here.
    public func viewDidDisappear() {
        syncProgressToServer()
        if !WatchNowPlayingState.shared.isActive(self) {
            teardown()
        }
    }

    /// Releases everything that outlives this instance: the periodic time
    /// observer, the progress loop and the handlers on the shared remote
    /// command centre. `deinit` cannot touch `@MainActor` state, so a session
    /// ends through here.
    public func teardown() {
        stopProgressUpdates()
        persistLocalPosition()
        avPlayer?.pause()
        localPlayer?.stop()
        isPlaying = false
        teardownHandles.releaseAll()
        updateNowPlayingPlaybackState()
        WatchNowPlayingState.shared.clearIfMatching(self)
    }

    public func downloadAudio() async {
        guard !isDownloading, !isDownloaded else { return }
        isDownloading = true

        do {
            var resolvedMediaUrl = mediaUrl
            if resolvedMediaUrl == nil {
                let fullVideo = try await videoService.getVideo(
                    config: serverConfig,
                    id: videoId
                )
                resolvedMediaUrl = fullVideo.mediaUrl
            }

            let item = WatchDownloadItem(
                videoId: videoId,
                title: title,
                channelName: channelName,
                mediaUrl: resolvedMediaUrl,
                duration: duration > 0 ? Int(duration) : nil,
                durationStr: nil,
                thumbPath: thumbPath
            )
            try await WatchDownloadManager.shared.downloadAudio(
                video: item,
                config: serverConfig
            )
            isDownloaded = true
        } catch {}
        isDownloading = false
    }

    public func deleteDownload() async {
        try? await WatchDownloadManager.shared.deleteDownload(videoId: videoId)
        isDownloaded = false
        // The file this player was reading is gone, so the session ends with it.
        teardown()
    }

    // MARK: - Streaming Setup

    private func setupStreaming(video: VideoResponse) async {
        do {
            let fullVideo: VideoResponse
            if video.mediaUrl != nil {
                fullVideo = video
            } else {
                fullVideo = try await videoService.getVideo(
                    config: serverConfig,
                    id: video.videoId
                )
            }

            guard let mediaPath = fullVideo.mediaUrl,
                  let mediaURL = serverConfig.fullURL(for: mediaPath) else {
                isLoading = false
                return
            }

            let asset = AVURLAsset(
                url: mediaURL,
                options: ["AVURLAssetHTTPHeaderFieldsKey": serverConfig.authHeaders]
            )
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            self.avPlayer = player

            // Observe duration
            let durationValue = try await asset.load(.duration)
            duration = CMTimeGetSeconds(durationValue)

            // Seek to watch progress if available
            if let watchPosition = fullVideo.player?.position, watchPosition > 0 {
                await player.seek(to: CMTime(seconds: Double(watchPosition), preferredTimescale: 1))
            }

            // Periodic time observer. The block is `@Sendable` and nonisolated,
            // but it is delivered on the main queue, so it can assume the main
            // actor rather than write to it from off it.
            let observer = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 1, preferredTimescale: 1),
                queue: .main
            ) { [weak self] time in
                MainActor.assumeIsolated {
                    self?.updateStreamingProgress(seconds: CMTimeGetSeconds(time))
                }
            }
            teardownHandles.add { player.removeTimeObserver(observer) }

            isLoading = false
            configureNowPlaying()
            updateNowPlayingPlaybackState()
        } catch {
            isLoading = false
        }
    }

    // MARK: - Local Playback

    private func setupLocalPlayer(
        fileURL: URL,
        startPosition: TimeInterval
    ) {
        do {
            localPlayer = try AVAudioPlayer(contentsOf: fileURL)
            localPlayer?.prepareToPlay()
            duration = localPlayer?.duration ?? 0

            if startPosition > 0 {
                localPlayer?.currentTime = startPosition
            }
            lastPersistedPosition = startPosition
            updateLocalProgress()
            isLoading = false
            configureNowPlaying()
            updateNowPlayingPlaybackState()
        } catch {
            isLoading = false
        }
    }

    // MARK: - Progress

    private func startProgressUpdates() {
        stopProgressUpdates()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.updateLocalProgress()
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func updateLocalProgress() {
        guard let localPlayer, duration > 0 else { return }
        elapsed = localPlayer.currentTime
        progress = elapsed / duration
        updateNowPlayingElapsed()
        persistLocalPositionIfDue()
    }

    private func updateStreamingProgress(seconds: TimeInterval) {
        elapsed = seconds
        if duration > 0 {
            progress = elapsed / duration
        }
        updateNowPlayingElapsed()
        persistLocalPositionIfDue()
    }

    /// The server position isn't readable offline, so a downloaded video keeps
    /// its own copy — without it every download restarted from the beginning.
    private func persistLocalPosition() {
        guard !isStreaming || isDownloaded else { return }
        lastPersistedPosition = elapsed
        WatchDownloadCatalog.shared.updatePosition(
            videoId: videoId,
            position: elapsed
        )
    }

    private func persistLocalPositionIfDue() {
        guard abs(elapsed - lastPersistedPosition) >= 10 else { return }
        persistLocalPosition()
    }

    // MARK: - Audio Session & Now Playing

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {}
    }

    private func configureNowPlaying() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = channelName
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    }

    private func updateNowPlayingPlaybackState() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipBackwardCommand.preferredIntervals = [15]

        // The command centre is shared, so drop whatever an earlier player left
        // on it and remember our own registrations for `teardown()`.
        addRemoteTarget(to: center.playCommand) { $0.togglePlayPause() }
        addRemoteTarget(to: center.pauseCommand) { $0.togglePlayPause() }
        addRemoteTarget(to: center.skipForwardCommand) { $0.skipForward() }
        addRemoteTarget(to: center.skipBackwardCommand) { $0.skipBackward() }
    }

    private func addRemoteTarget(
        to command: MPRemoteCommand,
        handler: @escaping @MainActor (WatchAudioPlayerViewModel) -> Void
    ) {
        command.removeTarget(nil)
        let token = command.addTarget { [weak self] _ in
            guard let self else { return .noSuchContent }
            handler(self)
            return .success
        }
        teardownHandles.add { command.removeTarget(token) }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
#endif
