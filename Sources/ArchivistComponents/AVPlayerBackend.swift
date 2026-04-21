#if !os(watchOS)
import AVFoundation
import Foundation

@MainActor
public final class AVPlayerBackend: PlayerBackend {
    public private(set) var avPlayer: AVPlayer?
    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0

    public var onTimeUpdate: ((Double) -> Void)?
    public var onStateChange: (() -> Void)?
    public var onPlaybackEnd: (() -> Void)?

    private var timeObserver: Any?
    private var durationObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var playbackEndContinuation: AsyncStream<Void>.Continuation?

    #if !os(tvOS)
    public var onPiPStopped: (() -> Void)?
    #endif

    public init() {}

    public func load(
        url: URL,
        startPosition: Double?,
        authHeaders: [String: String]
    ) {
        stop()

        let asset: AVURLAsset
        if authHeaders.isEmpty {
            asset = AVURLAsset(url: url)
        } else {
            asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": authHeaders]
            )
        }
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 60

        let player = AVPlayer(playerItem: item)
        player.allowsExternalPlayback = true
        player.automaticallyWaitsToMinimizeStalling = true

        if let position = startPosition, position > 0 {
            player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                self.onTimeUpdate?(time.seconds)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playbackEndContinuation?.yield()
                self?.onPlaybackEnd?()
            }
        }

        statusObservation = player.observe(
            \.timeControlStatus,
            options: [.new, .old]
        ) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = player.timeControlStatus == .playing
                self.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.onStateChange?()
            }
        }

        durationObservation = item.observe(
            \.duration,
            options: [.new]
        ) { [weak self] item, _ in
            let seconds = item.duration.seconds
            guard seconds.isFinite else { return }
            Task { @MainActor in
                self?.duration = seconds
                self?.onStateChange?()
            }
        }

        player.play()
        avPlayer = player
        isPlaying = true

    }

    public func play() {
        avPlayer?.play()
        isPlaying = true
    }

    public func pause() {
        avPlayer?.pause()
        isPlaying = false
    }

    public func stop() {
        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        durationObservation?.invalidate()
        durationObservation = nil
        avPlayer?.pause()
        avPlayer = nil
        isPlaying = false
        isBuffering = true
        currentTime = 0
        duration = 0
        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
    }

    public func seekTo(_ seconds: Double) {
        avPlayer?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    /// Swap the current AVPlayerItem to one backed by a local file, preserving
    /// playback position. Called by PlayerManager when the PlaybackCache has
    /// finished downloading in parallel with streaming playback.
    public func swapToLocalFile(_ fileURL: URL) {
        guard fileURL.isFileURL, let player = avPlayer else { return }

        let resumeTime = player.currentTime()
        let wasPlaying = player.timeControlStatus == .playing

        // Rebuild the item-scoped observers for the new item.
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        durationObservation?.invalidate()
        durationObservation = nil

        let newItem = AVPlayerItem(asset: AVURLAsset(url: fileURL))
        newItem.preferredForwardBufferDuration = 60

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newItem,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playbackEndContinuation?.yield()
                self?.onPlaybackEnd?()
            }
        }

        durationObservation = newItem.observe(
            \.duration,
            options: [.new]
        ) { [weak self] item, _ in
            let seconds = item.duration.seconds
            guard seconds.isFinite else { return }
            Task { @MainActor in
                self?.duration = seconds
                self?.onStateChange?()
            }
        }

        player.replaceCurrentItem(with: newItem)
        player.seek(to: resumeTime) { [weak self] _ in
            if wasPlaying {
                self?.avPlayer?.play()
            }
        }
    }

    public func playbackEndEvents() -> AsyncStream<Void> {
        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
        return AsyncStream { continuation in
            self.playbackEndContinuation = continuation
        }
    }
}
#endif
