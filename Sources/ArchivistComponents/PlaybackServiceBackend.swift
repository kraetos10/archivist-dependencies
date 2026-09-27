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
public final class PlaybackServiceBackend: NSObject, PlayerBackend, VLCPlaybackServiceDelegate {
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
    public var onPlaybackFailed: (() -> Void)?
    public var onPiPStateChanged: ((Bool) -> Void)?

    /// Resume position in seconds applied once libvlc reports the
    /// stream as seekable. Mirrors the deferred-seek pattern from
    /// the VLCUI backend — `:start-time=` is best-effort for HTTP.
    private var pendingResumeSec: Double = 0
    /// Sticky flag set once we've observed `.playing` for the current
    /// media. Gates the deferred resume seek and position propagation
    /// so neither fires against a stream that hasn't started yet.
    private var hasReachedPlaying = false

    /// Furthest point playback actually reached, rather than the last value
    /// libvlc reported. The end-of-media check reads this because a stray
    /// low or zero position update as the stream tears down would otherwise
    /// make a finished video look like one that stopped early.
    private var furthestTime: Double = 0

    /// Set while *we* are tearing the current media down — an explicit stop,
    /// or the cache swap replacing the source mid-playback. libvlc reports
    /// those as `.stopped` exactly like reaching the end of a video, and
    /// reporting them as an ending marks the video watched and auto-advances.
    private var isTransitioningMedia = false

    /// Set once libvlc reports `.opening` for media *this* backend loaded.
    ///
    /// `PlaybackService` is a process singleton reusing one media player, and
    /// it delivers state changes asynchronously to whichever delegate is
    /// current at delivery time. When a new video is loaded mid-playback,
    /// `PlayerManager` stops the outgoing backend and this one takes over
    /// the delegate in the same run-loop turn — so the outgoing media's
    /// `.paused` / `.stopping` / `.stopped` land *here*. Before this gate a
    /// stale `.stopped` looked like our own load failing (no `.playing`
    /// yet), and surfaced as `playbackFailed` for the new video. Until our
    /// own `.opening` arrives, those states can only belong to the previous
    /// media, so they are ignored. `.error` is not gated: a genuine failure
    /// of our media must always surface.
    private var hasOpenedOwnMedia = false

    /// How close to the end a stop has to be to count as reaching the end.
    /// libvlc's last position update lands a beat before the true end.
    private static let endOfMediaTolerance: Double = 10

    /// Whether a `.stopped` means the video finished, rather than failed.
    ///
    /// A stop before ever reaching `.playing` is a failed load — a dead URL,
    /// an unreachable server, an unplayable file. Without this check that was
    /// reported as an ending, which is why a video that wouldn't load looked
    /// like it skipped instantly to the end: it was marked watched, its
    /// resume position deleted, and auto-advance moved on.
    private var didReachEndOfMedia: Bool {
        guard hasReachedPlaying else { return false }
        // No duration to judge against — keep the old assumption rather than
        // refuse to advance at the end of media libvlc can't measure.
        guard duration > 0 else { return true }
        return furthestTime >= duration - Self.endOfMediaTolerance
    }

    private var service: PlaybackService { .sharedInstance() }

    override public init() {
        super.init()
    }

    public func load(url: URL, startPosition: Double?) {
        isBuffering = true
        isPlaying = true
        hasReachedPlaying = false
        hasOpenedOwnMedia = false
        furthestTime = 0
        if let startPosition, startPosition > 0 {
            currentTime = startPosition
            onTimeUpdate?(currentTime)
            pendingResumeSec = startPosition
        } else {
            pendingResumeSec = 0
        }

        // Resume is applied via the deferred `playbackPosition` seek in
        // `handlePositionUpdate` once libvlc reports the stream seekable —
        // NOT via `:start-time=`. Over HTTP, `:start-time=` makes libvlc
        // report a *relative* timeline (`mediaDuration` = remaining length,
        // `playbackTime` starting at 0), which surfaced as a total showing
        // only "what's left" and a progress bar pinned at 0. Loading the
        // full media keeps the timeline absolute so the deferred seek lands
        // the resume point against the true duration.
        // libvlc rejects some URLs outright; report that like any other
        // playback failure rather than trapping.
        guard let media = VLCMedia(url: url) else {
            isBuffering = false
            isPlaying = false
            onPlaybackFailed?()
            return
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
        isTransitioningMedia = true
        furthestTime = 0
        service.stopPlayback()
        service.delegate = nil
        service.videoOutputView = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        pendingResumeSec = 0
        hasReachedPlaying = false
        hasOpenedOwnMedia = false
    }

    public func seekTo(_ seconds: Double) {
        guard seconds >= 0 else { return }
        let length = Double(service.mediaDuration) / 1000.0
        guard length > 0 else {
            pendingResumeSec = seconds
            return
        }
        service.playbackPosition = Float(min(max(seconds / length, 0), 1))
        // Reflect the new position immediately. While paused libvlc emits no
        // `playbackPositionUpdated` callback, so without this the UI's
        // `currentTime` never moves and the scrubber snaps back — making it
        // look like you can't seek while paused.
        currentTime = min(seconds, length)
        onTimeUpdate?(currentTime)
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
        // schedule the layout sweep after it (main-actor jobs drain from
        // the same main queue, behind it). Autoresizing propagates
        // frames down the chain but doesn't reliably invoke
        // `layoutSubviews` on VLCKit's CAMetalLayer-backed render view —
        // when that's skipped, the layer keeps its old `drawableSize`
        // and renders off-screen even though every UIView in the
        // hierarchy reports the new bounds.
        Task { @MainActor [weak self] in
            guard let self else { return }
            Self.forceLayoutSweep(self.playerView)
        }
    }

    /// Rebuild libvlc's audio output unit. A transient `AVAudioSession`
    /// interruption (a notification sound, a brief route blip) or a
    /// lock/unlock can stop the audio unit while VLC's video vout keeps
    /// running off its own clock — the sound goes silent but the picture
    /// keeps playing. libvlc doesn't restart the aout on its own;
    /// deselecting and re-selecting the current audio track forces it to
    /// rebuild against the now-active session without disturbing video.
    public func refreshAudio() {
        guard hasReachedPlaying else { return }
        let current = service.indexOfCurrentAudioTrack
        guard current >= 0 else { return }
        service.disableAudio()
        service.selectAudioTrack(at: current)
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
            let scale = view.window?.screen.nativeScale ?? view.traitCollection.displayScale
            let target = CGSize(
                width: view.bounds.width * scale,
                height: view.bounds.height * scale
            )
            if scale > 0, target.width > 0, target.height > 0, metalLayer.drawableSize != target {
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

        // Resume via the deferred `playbackPosition` seek in
        // `handlePositionUpdate` (pinned to `pendingResumeSec` above), NOT
        // `:start-time=`. Same reason as `load()`: `:start-time=` makes
        // libvlc report a relative timeline for the swapped-in file
        // (`mediaDuration` = remaining, `playbackTime` from 0), so after the
        // cache swap the total and current times collapsed to "time left"
        // instead of the true duration. Loading the file whole keeps the
        // timeline absolute so the seek lands against the real length.
        // Replacing the media stops the outgoing one, and libvlc reports that
        // stop the same way it reports reaching the end.
        isTransitioningMedia = true
        hasOpenedOwnMedia = false

        // The swap is an optimisation: if libvlc won't take the local file,
        // leave the streaming media playing rather than trapping.
        guard let media = VLCMedia(url: fileURL) else {
            isTransitioningMedia = false
            return
        }
        let list = VLCMediaList()
        list.add(media)
        service.playMediaList(list, firstIndex: 0, subtitlesFilePath: nil)
    }

    public func setPlaybackRate(_ rate: Float) {
        service.playbackRate = rate
    }

    // MARK: - VLCPlaybackServiceDelegate

    // `PlaybackService` always calls its delegate from the main queue
    // (every call site is inside `DispatchQueue.main.async`). Handling the
    // callbacks synchronously on the main actor keeps them in libvlc's
    // order — separate `Task` hops carry no ordering guarantee, and the
    // `.opening` gate above depends on seeing states in sequence.

    nonisolated public func playbackPositionUpdated(_ playbackService: PlaybackService) {
        MainActor.assumeIsolated { handlePositionUpdate() }
    }

    nonisolated public func mediaPlayerStateChanged(
        _ currentState: VLCMediaPlayerState,
        isPlaying: Bool,
        currentMediaHasTrackToChooseFrom: Bool,
        currentMediaHasChapters: Bool,
        for playbackService: PlaybackService
    ) {
        MainActor.assumeIsolated { handleStateChange(currentState) }
    }

    nonisolated public func pictureInPictureStateDidChange(enabled: Bool) {
        MainActor.assumeIsolated { onPiPStateChanged?(enabled) }
    }

    private func handlePositionUpdate() {
        let lengthMs = service.mediaDuration
        if lengthMs > 0 {
            duration = Double(lengthMs) / 1000.0
        }

        // Suppress position propagation until the new media has reached
        // `.playing`. libvlc can emit transient `playbackTime` values
        // during the load/swap window — either stale from the prior media
        // or zero before `:start-time=` is honoured.
        guard hasReachedPlaying else { return }

        // While a resume seek is pending, pin the progress bar at the
        // resume point instead of propagating libvlc's transient
        // `playbackTime` — right after a cache swap it reads 0 for a tick
        // (before `:start-time` lands), which flashed the bar back to the
        // start and then jumped forward. Apply the seek once the media is
        // seekable and reports a trustworthy duration (always longer than
        // the resume target), dividing by the *current* media's own
        // duration so the landing is exact even when the local file's
        // length differs slightly from the stream's.
        if pendingResumeSec > 0 {
            currentTime = pendingResumeSec
            furthestTime = max(furthestTime, currentTime)
            onTimeUpdate?(currentTime)
            guard service.isSeekable, duration >= pendingResumeSec else { return }
            service.playbackPosition = Float(min(max(pendingResumeSec / duration, 0), 1))
            pendingResumeSec = 0
            return
        }

        let timeMs = service.playbackTime.intValue
        currentTime = Double(timeMs) / 1000.0
        furthestTime = max(furthestTime, currentTime)
        onTimeUpdate?(currentTime)
    }

    private func handleStateChange(_ currentState: VLCMediaPlayerState) {
        if !hasOpenedOwnMedia {
            switch currentState {
            case .paused, .stopping, .stopped:
                // The previous media winding down; see `hasOpenedOwnMedia`.
                return
            default:
                break
            }
        }
        switch currentState {
        case .opening:
            hasOpenedOwnMedia = true
            // The replacement media is opening, so the outgoing one's stop
            // has been and gone.
            isTransitioningMedia = false
            // VLCKit 4.0.0-a22 dropped the `.buffering` state; buffer fill
            // now arrives via `mediaPlayerBufferingChanged:`. We only ever
            // showed the spinner between `.opening` and the first
            // `.playing` anyway (mid-stream refills were deliberately
            // ignored), so that window is unchanged.
            isBuffering = true
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
            let reachedEnd = didReachEndOfMedia
            let wasOurTeardown = isTransitioningMedia
            hasReachedPlaying = false
            isTransitioningMedia = false
            if wasOurTeardown {
                // We asked for this stop; it says nothing about the video.
                break
            }
            if reachedEnd {
                onPlaybackEnd?()
            } else {
                onPlaybackFailed?()
            }
        case .stopping:
            // Stop was requested and libvlc is tearing the stream down.
            // Playback-end is signalled on `.stopped`, so don't yield here.
            isPlaying = false
            isBuffering = false
        case .error:
            isPlaying = false
            isBuffering = false
            hasReachedPlaying = false
            isTransitioningMedia = false
            onPlaybackFailed?()
        @unknown default:
            break
        }
        onStateChange?()
    }
}
#endif
