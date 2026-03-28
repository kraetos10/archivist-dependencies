import AVFoundation
import AVKit
#if !os(tvOS)
import UIKit
#endif

@Observable
@MainActor
public final class PlayerManager {
    public static let shared = PlayerManager()

    public private(set) var player: AVPlayer?
    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0
    public var currentVideoID: String?
    public var isInPiP = false
    public var activePiPDelegate: AnyObject?
    #if !os(tvOS)
    public weak var activePlayerViewController: AVPlayerViewController?
    #endif
    private var timeObserver: Any?
    private var durationObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    public var onPlaybackEnd: (() -> Void)?
    public var onPause: (() -> Void)?

    private init() {}

    // MARK: - Playback Control

    public func load(url: URL, startPosition: Double?) {
        stop()

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        createPlayer(url: url, startPosition: startPosition)
    }

    public func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
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
        player?.pause()
        player = nil
        isPlaying = false
        isBuffering = true
        currentTime = 0
        duration = 0
        onPlaybackEnd = nil
        onPause = nil
        currentVideoID = nil
        isInPiP = false
        activePiPDelegate = nil
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        onPause?()
    }

    public func resume() {
        player?.play()
        isPlaying = true
    }

    public func seekTo(_ seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    public func skipForward(_ seconds: Double = 10) {
        let target = min(currentTime + seconds, duration)
        seekTo(target)
    }

    public func skipBackward(_ seconds: Double = 10) {
        let target = max(currentTime - seconds, 0)
        seekTo(target)
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    #if !os(tvOS)
    public func stopPiP() {
        guard isInPiP else { return }
        // Remove the player from the PiP VC to force PiP to end
        activePlayerViewController?.player = nil
        isInPiP = false
        activePiPDelegate = nil
        activePlayerViewController = nil
    }
    #endif

    // MARK: - Private

    private func createPlayer(url: URL, startPosition: Double?) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 30

        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.allowsExternalPlayback = true
        avPlayer.automaticallyWaitsToMinimizeStalling = true

        if let position = startPosition, position > 0 {
            avPlayer.seek(to: CMTime(seconds: position, preferredTimescale: 600))
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onPlaybackEnd?()
        }

        statusObservation = avPlayer.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] player, change in
            Task { @MainActor in
                let wasPlaying = self?.isPlaying ?? false
                self?.isPlaying = player.timeControlStatus == .playing
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                // Fire onPause when transitioning from playing to paused
                if wasPlaying && player.timeControlStatus == .paused {
                    self?.onPause?()
                }
            }
        }

        durationObservation = item.observe(\.duration, options: [.new]) { [weak self] item, _ in
            let seconds = item.duration.seconds
            guard seconds.isFinite else { return }
            Task { @MainActor in
                self?.duration = seconds
            }
        }

        avPlayer.play()
        player = avPlayer
        isPlaying = true
    }
}
