#if !os(watchOS)
import Foundation
import UIKit
import VLCKit

@MainActor
public final class VLCPlayerBackend: NSObject, PlayerBackend, @unchecked Sendable {
    public var mediaPlayer: VLCMediaPlayer

    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0

    public var onTimeUpdate: ((Double) -> Void)?
    public var onStateChange: (() -> Void)?
    public var onPlaybackEnd: (() -> Void)?

    private var playbackEndContinuation: AsyncStream<Void>.Continuation?
    private var pendingStartPosition: Double?
    /// When a start-position seek is in flight, suppress time updates until
    /// VLC reports a time within 2s of this target (avoids a visible bounce
    /// back to 0 from stale notifications queued before the seek).
    private var seekTargetTime: Double?
    /// Sticky flag set in `handleTimeChange` once we've observed a time
    /// near the duration. VLC sometimes resets `mediaPlayer.time` to 0 just
    /// before firing `.stopped` on natural end-of-media, so checking the
    /// current time at state-change time alone misses the event.
    private var reachedEndOfMedia = false
    private var loadedMedia: VLCMedia?
    private var drawableView: UIView?

    // PiP
    weak var pipController: VLCPictureInPictureWindowControlling?
    /// Strong reference to keep the drawable alive during PiP
    /// (SwiftUI will dismantle the UIViewRepresentable's view on dismiss).
    var pipDrawableRetain: UIView?
    public var onPiPStarted: (() -> Void)?
    public var onPiPStopped: (() -> Void)?
    public var onPiPRestoreRequested: (() -> Void)?

    override public init() {
        mediaPlayer = VLCMediaPlayer()
        super.init()
        mediaPlayer.delegate = self
    }

    public func load(
        url: URL,
        startPosition: Double?
    ) {
        pendingStartPosition = startPosition
        reachedEndOfMedia = false
        isBuffering = true
        // Seed the UI with the resume position so the seek bar renders at the
        // correct spot from the first frame instead of flashing 0:00.
        if let startPosition, startPosition > 0 {
            currentTime = startPosition
            onTimeUpdate?(currentTime)
        }

        startPlayback(url: url)
    }

    public func attachDrawable(_ view: UIView) {
        let wasPlaying = mediaPlayer.isPlaying
        let resumeTime = mediaPlayer.time
        drawableView = view
        mediaPlayer.drawable = view

        // Nudge the video output pipeline onto the new drawable if VLC is
        // already mid-playback. If we're called before `startPlayback`'s
        // `play()` has flipped `isPlaying` true (initial-load race) we'd
        // previously fall through to an `else if loadedMedia != nil` branch
        // that ended with `pause()` — killing playback. Just skip the nudge
        // in that case; VLC picks up the drawable reference on its own.
        if wasPlaying {
            mediaPlayer.pause()
            mediaPlayer.play()
            mediaPlayer.time = resumeTime
        }
    }

    // MARK: - PiP

    public func startPiP() {
        // Retain the drawable so it survives SwiftUI view dismissal
        pipDrawableRetain = drawableView
        pipController?.startPictureInPicture()
    }

    public func stopPiP() {
        pipController?.stopPictureInPicture()
        pipDrawableRetain = nil
    }

    public func updatePiPState() {
        pipController?.invalidatePlaybackState()
    }

    public func play() {
        mediaPlayer.play()
        isPlaying = true
    }

    public func pause() {
        mediaPlayer.pause()
        isPlaying = false
        isBuffering = false
        onStateChange?()
    }

    public func stop() {
        mediaPlayer.stop()
        mediaPlayer.drawable = nil
        mediaPlayer.media = nil
        loadedMedia = nil
        drawableView = nil
        pipDrawableRetain = nil
        pipController = nil

        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        pendingStartPosition = nil
        seekTargetTime = nil
        reachedEndOfMedia = false

        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
    }

    public func seekTo(_ seconds: Double) {
        guard seconds >= 0 else { return }
        seekTargetTime = nil
        let milliseconds = Int32(seconds * 1000)
        mediaPlayer.time = VLCTime(int: milliseconds)
    }

    public func playbackEndEvents() -> AsyncStream<Void> {
        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
        return AsyncStream { continuation in
            self.playbackEndContinuation = continuation
        }
    }

    // MARK: - Playback

    private func startPlayback(url: URL) {
        guard let media = VLCMedia(url: url) else {
            isBuffering = false
            return
        }

        Self.applyStreamingOptions(to: media)

        // Resume-at-offset via a VLC media option. This bakes the start
        // position into the HTTP range request VLC issues, which is far more
        // reliable over a network stream than a post-play `mediaPlayer.position`
        // seek — the latter kept putting VLC into a half-loaded state on
        // Continue-Watching resumes and the video never started rendering.
        if let startPosition = pendingStartPosition, startPosition > 0 {
            media.addOption(":start-time=\(Int(startPosition))")
        }
        pendingStartPosition = nil
        loadedMedia = media

        if let view = drawableView {
            mediaPlayer.drawable = view
        }
        mediaPlayer.media = media
        mediaPlayer.play()
        isPlaying = true
    }

    /// Swap to a local `file://` URL at the current playback position. Called
    /// from `PlayerManager` after the parallel `PlaybackCache` download finishes
    /// so subsequent seeks read from disk.
    public func swapToLocalFile(_ fileURL: URL) {
        guard fileURL.isFileURL,
              let newMedia = VLCMedia(url: fileURL) else { return }
        Self.applyStreamingOptions(to: newMedia)

        let resumeTime = currentTime
        loadedMedia = newMedia
        mediaPlayer.media = newMedia
        mediaPlayer.play()

        if resumeTime > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self.seekTo(resumeTime)
            }
        }
    }

    /// Applies VLC media options for playback.
    /// - `:network-caching=1500` — 1.5s buffer for fast startup while keeping smooth playback.
    /// - `:http-reconnect` — resilience for dropped connections.
    /// - `:file-caching=300` — minimal cache for local files (seeks are instant on disk).
    /// - `:input-fast-seek` — use keyframe-based seeking for snappier response.
    private static func applyStreamingOptions(to media: VLCMedia) {
        media.addOption(":network-caching=1500")
        media.addOption(":file-caching=300")
        media.addOption(":http-reconnect")
        media.addOption(":input-fast-seek")
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlayerBackend: VLCMediaPlayerDelegate {
    nonisolated public func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            self.handleStateChange()
        }
    }

    nonisolated public func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            self.handleTimeChange()
        }
    }

    private func handleStateChange() {
        let state = mediaPlayer.state

        switch state {
        case .playing:
            isPlaying = true
            isBuffering = false
        case .paused:
            isPlaying = false
            isBuffering = false
        case .buffering:
            if isPlaying || currentTime == 0 {
                isBuffering = true
            }
        case .stopped:
            isPlaying = false
            isBuffering = false
            // Clean end of media: VLC transitions to `.stopped` after it
            // played through. `reachedEndOfMedia` was latched in
            // `handleTimeChange` when the position crossed the duration.
            if reachedEndOfMedia {
                reachedEndOfMedia = false
                playbackEndContinuation?.yield()
                onPlaybackEnd?()
            }
        case .error:
            isPlaying = false
            isBuffering = false
        default:
            break
        }
        onStateChange?()
    }

    private func handleTimeChange() {
        let timeMs = mediaPlayer.time.intValue
        let reportedTime = Double(timeMs) / 1000.0

        if let media = mediaPlayer.media {
            let lengthMs = media.length.intValue
            if lengthMs > 0 {
                duration = Double(lengthMs) / 1000.0
            }
        }

        // If a user-initiated seek is in flight, swallow time updates until
        // VLC actually lands near the target.
        if let target = seekTargetTime {
            if abs(reportedTime - target) < 2.0 {
                seekTargetTime = nil
                currentTime = reportedTime
                onTimeUpdate?(currentTime)
            }
            return
        }

        currentTime = reportedTime
        onTimeUpdate?(currentTime)

        // Latch "reached end" once we observe a time within 1s of the end.
        // VLC's `.stopped` state fires shortly after but may report time 0.
        if duration > 0, reportedTime > 0, reportedTime >= duration - 1 {
            reachedEndOfMedia = true
        }
    }
}
#endif
