#if os(iOS) || os(tvOS)
import Foundation
import UIKit
import VLCKit
import VLCPlayerCore

/// `PlayerBackend` adapter over `VLCPlayerKit.PlaybackService` (the
/// upstream-verbatim playback engine lifted from videolan/vlc-ios).
/// Replaces the VLCUI-based `VLCPlayerBackend` on iOS so we get
/// upstream's HTTP-MP4 seek behaviour while keeping our SwiftUI chrome
/// in `VLCPlayerView`. tvOS stays on the VLCUI backend.
@MainActor
public final class PlaybackServiceBackend: NSObject, PlayerBackend, VLCPlaybackServiceDelegate, @unchecked Sendable {
    /// Long-lived host view that the SwiftUI player chrome adopts.
    /// `PlaybackService` reparents its `_actualVideoOutputView` under
    /// this on `videoOutputView =` and survives mini-↔-full transitions
    /// without restarting playback.
    public let playerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0

    public var onTimeUpdate: ((Double) -> Void)?
    public var onStateChange: (() -> Void)?
    public var onPlaybackEnd: (() -> Void)?
    public var onPiPStateChanged: ((Bool) -> Void)?

    private var playbackEndContinuation: AsyncStream<Void>.Continuation?
    /// Resume position in seconds applied once libvlc reports the
    /// stream as seekable. Mirrors the deferred-seek pattern from
    /// the VLCUI backend — `:start-time=` is best-effort for HTTP.
    private var pendingResumeSec: Double = 0
    /// Sticky flag set once we've observed `.playing` for the current
    /// media. VLCKit emits transient `.buffering` events as the
    /// libvlc network buffer refills mid-stream; those aren't real
    /// stalls and shouldn't toggle the spinner.
    private var hasReachedPlaying = false

    private var service: PlaybackService { .sharedInstance() }

    override public init() {
        super.init()
    }

    public func load(url: URL, startPosition: Double?) {
        isBuffering = true
        isPlaying = true
        hasReachedPlaying = false
        if let startPosition, startPosition > 0 {
            currentTime = startPosition
            onTimeUpdate?(currentTime)
            pendingResumeSec = startPosition
        } else {
            pendingResumeSec = 0
        }

        let media = VLCMedia(url: url)!
        if pendingResumeSec > 0 {
            media.addOption(":start-time=\(Int(pendingResumeSec))")
        }
        let list = VLCMediaList()
        list.add(media)

        service.delegate = self
        service.videoOutputView = playerView
        service.playMediaList(list, firstIndex: 0, subtitlesFilePath: nil)
    }

    public func play() {
        service.play()
        isPlaying = true
        onStateChange?()
    }

    public func pause() {
        service.pause()
        isPlaying = false
        isBuffering = false
        onStateChange?()
    }

    public func stop() {
        service.stopPlayback()
        service.delegate = nil
        service.videoOutputView = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        pendingResumeSec = 0
        hasReachedPlaying = false
        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
    }

    public func seekTo(_ seconds: Double) {
        guard seconds >= 0 else { return }
        let length = Double(service.mediaDuration) / 1000.0
        guard length > 0 else {
            pendingResumeSec = seconds
            return
        }
        service.playbackPosition = Float(min(max(seconds / length, 0), 1))
    }

    /// Re-assign the video output view to the same host. libvlc's
    /// drawable binding is occasionally stuck on a stale layer after a
    /// rotation — audio keeps flowing while the picture goes black. Setting
    /// `videoOutputView` again forces `PlaybackService` to reparent its
    /// `_actualVideoOutputView` and rebind the rendering layer to the
    /// current host bounds.
    public func refreshDrawable() {
        guard service.videoOutputView != nil else { return }
        let host = playerView
        service.videoOutputView = nil
        service.videoOutputView = host
    }

    public func swapToLocalFile(_ fileURL: URL) {
        guard fileURL.isFileURL else { return }
        let resumeSec = max(currentTime, 0)
        pendingResumeSec = resumeSec
        // The new media has to re-prove it's playing before we trust any
        // position updates — without this, libvlc's transient `playbackTime`
        // and `mediaDuration` readings during the transition can drive the
        // deferred seek against the wrong divisor and land playback past the
        // resume point.
        hasReachedPlaying = false

        let media = VLCMedia(url: fileURL)!
        if resumeSec > 0 {
            media.addOption(":start-time=\(Int(resumeSec))")
        }
        let list = VLCMediaList()
        list.add(media)
        service.playMediaList(list, firstIndex: 0, subtitlesFilePath: nil)
    }

    public func setPlaybackRate(_ rate: Float) {
        service.playbackRate = rate
    }

    public func playbackEndEvents() -> AsyncStream<Void> {
        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
        return AsyncStream { continuation in
            self.playbackEndContinuation = continuation
        }
    }

    // MARK: - VLCPlaybackServiceDelegate

    nonisolated public func playbackPositionUpdated(_ playbackService: PlaybackService) {
        Task { @MainActor in self.handlePositionUpdate() }
    }

    nonisolated public func mediaPlayerStateChanged(
        _ currentState: VLCMediaPlayerState,
        isPlaying: Bool,
        currentMediaHasTrackToChooseFrom: Bool,
        currentMediaHasChapters: Bool,
        for playbackService: PlaybackService
    ) {
        Task { @MainActor in self.handleStateChange(currentState) }
    }

    nonisolated public func pictureInPictureStateDidChange(enabled: Bool) {
        Task { @MainActor in self.onPiPStateChanged?(enabled) }
    }

    private func handlePositionUpdate() {
        let lengthMs = service.mediaDuration
        if lengthMs > 0 {
            duration = Double(lengthMs) / 1000.0
        }

        // Suppress position propagation until the new media has reached
        // `.playing`. libvlc can emit transient `playbackTime` values
        // during the load/swap window — either stale from the prior media
        // or zero before `:start-time=` is honoured — and pairing them
        // with an unstable `mediaDuration` made the deferred seek land
        // ahead of the intended resume point.
        guard hasReachedPlaying else { return }

        let timeMs = service.playbackTime.intValue
        currentTime = Double(timeMs) / 1000.0
        onTimeUpdate?(currentTime)

        if pendingResumeSec > 0, service.isSeekable, duration > 0 {
            let target = pendingResumeSec
            if abs(currentTime - target) <= 2 {
                pendingResumeSec = 0
            } else {
                service.playbackPosition = Float(min(max(target / duration, 0), 1))
                pendingResumeSec = 0
            }
        }
    }

    private func handleStateChange(_ currentState: VLCMediaPlayerState) {
        switch currentState {
        case .opening:
            isBuffering = true
        case .buffering:
            // Only treat as buffering before the first .playing — VLCKit
            // emits .buffering as a buffer-fill heartbeat once playback
            // is underway, which would otherwise leave the spinner up.
            if !hasReachedPlaying {
                isBuffering = true
            }
        case .playing:
            hasReachedPlaying = true
            isPlaying = true
            isBuffering = false
        case .paused:
            isPlaying = false
            isBuffering = false
        case .stopped:
            isPlaying = false
            isBuffering = false
            hasReachedPlaying = false
            playbackEndContinuation?.yield()
            onPlaybackEnd?()
        case .error:
            isPlaying = false
            isBuffering = false
        @unknown default:
            break
        }
        onStateChange?()
    }
}
#endif
