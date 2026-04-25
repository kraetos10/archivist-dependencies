#if !os(watchOS)
import Foundation
import UIKit
import VLCKit

/// VLC playback backend, layered over VLCUI.
///
/// VLCUI's `UIVLCVideoPlayerView` owns the underlying `VLCMediaPlayer` and
/// the drawable surface. This backend keeps a long-lived player view as the
/// rendering surface and drives playback through VLCUI's `Proxy`. State and
/// time updates flow back via `onStateUpdated` / `onTicksUpdated`.
///
/// `PlayerManager` reparents the player view between mini and full hosts,
/// preserving the playback-without-restart UX we had when we owned the
/// drawable directly.
@MainActor
public final class VLCPlayerBackend: NSObject, PlayerBackend, @unchecked Sendable {
    /// Long-lived rendering surface. Created on first `load(...)` and
    /// reused for subsequent media swaps via `proxy.playNewMedia(_:)`.
    public private(set) var playerView: UIVLCVideoPlayerView?

    /// VLCUI command channel. Created up-front so the view we make in
    /// `load(...)` can register itself; outlives the view.
    public let proxy = VLCVideoPlayer.Proxy()

    /// Backwards-compatible accessor for callers that want the underlying
    /// `VLCMediaPlayer` directly (e.g. now-playing artwork pipeline).
    /// Forwards to whatever VLCUI is currently driving.
    public var mediaPlayer: VLCMediaPlayer? { proxy.mediaPlayer }

    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0

    public var onTimeUpdate: ((Double) -> Void)?
    public var onStateChange: (() -> Void)?
    public var onPlaybackEnd: (() -> Void)?

    private var playbackEndContinuation: AsyncStream<Void>.Continuation?
    /// Sticky flag set in `handleTicks` once we've observed a time near the
    /// duration. VLC sometimes resets time to 0 just before firing
    /// `.stopped`, so we latch from the time-updated callback.
    private var reachedEndOfMedia = false
    /// Resume target in milliseconds. Cleared once `handleTicks` confirms
    /// the player has actually landed within ~2s of it. Without this we'd
    /// rely solely on VLCUI's one-shot seek-on-first-tick, which silently
    /// fails for HTTP streams (their `isSeekable` lies briefly during
    /// startup).
    private var pendingResumeMs: Int = 0

    // PiP is driven directly through `playerView.pipController`. No
    // host-facing callback chain — system PiP manages its own UI lifecycle.

    override public init() {
        super.init()
    }

    public func load(
        url: URL,
        startPosition: Double?
    ) {
        reachedEndOfMedia = false
        isBuffering = true
        let resumeMs = Int((startPosition ?? 0) * 1000)
        pendingResumeMs = resumeMs

        if let startPosition, startPosition > 0 {
            // Seed the UI with the resume position so the seek bar renders at
            // the correct spot from the first frame instead of flashing 0:00.
            currentTime = startPosition
            onTimeUpdate?(currentTime)
        }

        // VLCUI's `setConfigurationValues` no longer sets `player.time` for
        // us (we patched it out — see the note in that method). We drive the
        // resume seek from the backend instead so we can keep retrying
        // across delegate callbacks until the seek actually lands.
        let configuration = makeConfiguration(url: url, resumeMs: 0)

        if playerView == nil {
            playerView = UIVLCVideoPlayerView(
                configuration: configuration,
                proxy: proxy,
                onTicksUpdated: { [weak self] ticks, info in
                    Task { @MainActor in self?.handleTicks(ticks: ticks, info: info) }
                },
                onStateUpdated: { [weak self] state, info in
                    Task { @MainActor in self?.handleState(state: state, info: info) }
                },
                loggingInfo: nil
            )
        } else {
            // Subsequent media swaps reuse the persistent surface so we don't
            // lose the on-screen view across video changes.
            proxy.playNewMedia(configuration)
        }

        isPlaying = true
    }

    /// Backwards compatible no-op on the VLCUI-backed path. The drawable is
    /// `UIVLCVideoPlayerView`'s internal `videoContentView`, so callers that
    /// used to hand us their own UIView surface should now host the
    /// `playerView` itself (see `VLCPlayerView`/`TVVLCPlayerView`).
    public func attachDrawable(_ view: UIView) {
        _ = view
    }

    // MARK: - PiP

    public func startPiP() {
        playerView?.pipController?.startPictureInPicture()
    }

    public func stopPiP() {
        playerView?.pipController?.stopPictureInPicture()
    }

    public func updatePiPState() {
        playerView?.pipController?.invalidatePlaybackState()
    }

    public func play() {
        proxy.play()
        isPlaying = true
    }

    public func pause() {
        proxy.pause()
        isPlaying = false
        isBuffering = false
        onStateChange?()
    }

    public func stop() {
        proxy.stop()
        playerView = nil

        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        pendingResumeMs = 0
        reachedEndOfMedia = false

        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
    }

    public func seekTo(_ seconds: Double) {
        guard seconds >= 0 else { return }
        proxy.setTime(.seconds(Int(seconds)))
    }

    public func playbackEndEvents() -> AsyncStream<Void> {
        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
        return AsyncStream { continuation in
            self.playbackEndContinuation = continuation
        }
    }

    /// Swap to a local `file://` URL at the current playback position. Called
    /// from `PlayerManager` after the parallel `PlaybackCache` download
    /// finishes so subsequent seeks read from disk.
    public func swapToLocalFile(_ fileURL: URL) {
        guard fileURL.isFileURL else { return }
        let resumeMs = Int(currentTime * 1000)
        let configuration = makeConfiguration(url: fileURL, resumeMs: resumeMs)
        proxy.playNewMedia(configuration)
    }

    // MARK: - VLCUI callbacks

    private func handleTicks(ticks: Int, info: VLCVideoPlayer.PlaybackInformation) {
        let reportedTime = Double(ticks) / 1000.0
        if info.length > 0 {
            duration = Double(info.length) / 1000.0
        }

        // One-shot resume seek: as soon as VLC reports it's seekable,
        // jump to the target and stop tracking it. No retry loop — that
        // pattern was wedging the decoder. If the user's URL doesn't end
        // up seekable in time, we'd rather play from 0:00 than stall.
        if pendingResumeMs > 0,
           let player = proxy.mediaPlayer,
           player.isSeekable {
            player.time = VLCTime(int: Int32(pendingResumeMs))
            pendingResumeMs = 0
        }

        currentTime = reportedTime
        onTimeUpdate?(currentTime)

        // Latch "reached end" once we observe a time within 1s of the end.
        // VLCKit's `.stopped` state fires shortly after but may report time 0.
        if duration > 0, reportedTime > 0, reportedTime >= duration - 1 {
            reachedEndOfMedia = true
        }
    }

    private func handleState(state: VLCVideoPlayer.State, info: VLCVideoPlayer.PlaybackInformation) {
        switch state {
        case .opening:
            // Stream is being resolved — show buffering immediately rather
            // than waiting for the first `.buffering` tick.
            isBuffering = true
        case .playing:
            isPlaying = true
            isBuffering = false
            applyPendingResume()
        case .paused:
            isPlaying = false
            isBuffering = false
        case .buffering, .esAdded:
            if isPlaying || currentTime == 0 {
                isBuffering = true
            }
        case .ended, .stopped:
            isPlaying = false
            isBuffering = false
            if reachedEndOfMedia {
                reachedEndOfMedia = false
                playbackEndContinuation?.yield()
                onPlaybackEnd?()
            }
        case .error:
            isPlaying = false
            isBuffering = false
        }
        onStateChange?()
    }

    /// Issue the resume seek once if VLC reports the stream as seekable.
    /// `handleTicks` does the same check — this just gives us a slightly
    /// earlier shot when `.playing` fires before the first tick.
    private func applyPendingResume() {
        guard pendingResumeMs > 0,
              let player = proxy.mediaPlayer,
              player.isSeekable else { return }
        player.time = VLCTime(int: Int32(pendingResumeMs))
        pendingResumeMs = 0
    }

    // MARK: - Helpers

    private func makeConfiguration(url: URL, resumeMs: Int) -> VLCVideoPlayer.Configuration {
        var configuration = VLCVideoPlayer.Configuration(url: url)
        configuration.autoPlay = true
        configuration.startTime = .ticks(resumeMs)
        configuration.options = Self.streamingOptions
        return configuration
    }

    /// VLC media options applied to every load.
    /// - `:network-caching=1500` — 1.5s buffer for fast startup while keeping smooth playback.
    /// - `:http-reconnect` — resilience for dropped connections.
    /// - `:file-caching=300` — minimal cache for local files (seeks are instant on disk).
    /// - `:input-fast-seek` — keyframe-based seeking for snappier response.
    private static let streamingOptions: [String: Any] = [
        "network-caching": 1500,
        "file-caching": 300,
        "http-reconnect": true,
        "input-fast-seek": true
    ]
}
#endif
