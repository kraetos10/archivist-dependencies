#if os(iOS) || os(tvOS)
import Foundation
import QuartzCore
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
        // Skip during PiP — VLCKit's PiP path renders through its own
        // window/drawable, and tearing down the host binding mid-PiP stalls
        // the pipeline (visible as lag/freezes when entering or living in
        // PiP). The host's bounds-change debounce in `VLCPlayerHostView`
        // fires while the detail screen dismisses to PiP, so this is a
        // hot path. PiP is iOS-only in PlaybackService.
        #if os(iOS)
        if service.isPipEnabled { return }
        #endif
        let host = playerView
        service.videoOutputView = nil
        service.videoOutputView = host
        // `setVideoOutputView` runs on the next main-queue tick, so
        // schedule the layout sweep after it. Autoresizing propagates
        // frames down the chain but doesn't reliably invoke
        // `layoutSubviews` on VLCKit's CAMetalLayer-backed render view —
        // when that's skipped, the layer keeps its old `drawableSize`
        // and renders off-screen even though every UIView in the
        // hierarchy reports the new bounds.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Self.forceLayoutSweep(self.playerView)
        }
    }

    private static func forceLayoutSweep(_ view: UIView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        // VLCKit renders into a `CAMetalLayer` somewhere inside this
        // hierarchy. Autoresizing propagates the UIView frame on rotation
        // but `CAMetalLayer.drawableSize` does NOT auto-update from
        // `bounds` changes — the layer keeps rendering into a surface
        // sized for the previous orientation, which composites as black
        // (or a tiny tile) inside the new bounds. Pause+play doesn't
        // recover it because the stale drawable size is what the vout
        // module is configured for. Explicitly retarget the drawable
        // size for any Metal layer in the subtree so the next frame
        // renders at the correct resolution.
        if let metalLayer = view.layer as? CAMetalLayer {
            let scale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
            let target = CGSize(
                width: view.bounds.width * scale,
                height: view.bounds.height * scale
            )
            if target.width > 0, target.height > 0, metalLayer.drawableSize != target {
                metalLayer.drawableSize = target
            }
        }
        for sub in view.subviews {
            forceLayoutSweep(sub)
        }
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
            // Fractional seconds: libvlc accepts a float here. Truncating
            // to whole seconds nudged the initial landing earlier in time,
            // which combined with libvlc's keyframe rounding made the
            // post-swap reconcile seek visibly skip forward.
            media.addOption(":start-time=\(String(format: "%.3f", resumeSec))")
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
            // Always reconcile — `:start-time` rounds to a keyframe and
            // can land seconds ahead of the captured position, which on a
            // cache swap shows up as a visible forward skip. An accurate
            // seek snaps us back to where the user actually was.
            service.playbackPosition = Float(min(max(target / duration, 0), 1))
            pendingResumeSec = 0
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
