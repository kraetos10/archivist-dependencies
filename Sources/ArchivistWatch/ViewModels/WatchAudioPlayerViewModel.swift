#if os(watchOS)
import AVFoundation
import ArchivistNetworking
import Foundation
import MediaPlayer

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

    private let videoId: String
    private var mediaUrl: String?
    public let serverConfig: ServerConfig
    private var avPlayer: AVPlayer?
    private var localPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var timeObserver: Any?
    private let videoService: any VideoServiceType
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
        videoService: any VideoServiceType = VideoService()
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
        videoService: any VideoServiceType = VideoService(),
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
                stopProgressTimer()
                syncProgressToServer()
            } else {
                localPlayer.play()
                isPlaying = true
                startProgressTimer()
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
        Task {
            try? await videoService.setProgress(
                config: serverConfig,
                videoId: videoId,
                position: Int(elapsed)
            )
        }
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

            // Periodic time observer
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 1, preferredTimescale: 1),
                queue: .main
            ) { [weak self] time in
                guard let self else { return }
                self.elapsed = CMTimeGetSeconds(time)
                if self.duration > 0 {
                    self.progress = self.elapsed / self.duration
                }
                self.updateNowPlayingElapsed()
            }

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
            updateLocalProgress()
            isLoading = false
            configureNowPlaying()
            updateNowPlayingPlaybackState()
        } catch {
            isLoading = false
        }
    }

    // MARK: - Progress

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateLocalProgress()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateLocalProgress() {
        guard let localPlayer, duration > 0 else { return }
        elapsed = localPlayer.currentTime
        progress = elapsed / duration
        updateNowPlayingElapsed()
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

        center.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
#endif
