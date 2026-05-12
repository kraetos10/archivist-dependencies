#if !os(watchOS)
import Foundation

@MainActor
public protocol PlayerBackend: AnyObject {
    var isPlaying: Bool { get }
    var isBuffering: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }

    func load(
        url: URL,
        startPosition: Double?
    )
    func play()
    func pause()
    func stop()
    func seekTo(_ seconds: Double)

    /// Replace the current playback source with a local `file://` URL,
    /// preserving the current playback position. Called by `PlayerManager`
    /// when the parallel `PlaybackCache` download finishes mid-playback so
    /// subsequent seeks read from disk.
    func swapToLocalFile(_ fileURL: URL)

    /// Apply a playback-rate multiplier (1.0 = normal, 4.0 = 4x fast
    /// forward, 0.5 = half speed). Used by the tvOS player to
    /// fast-forward while the user holds the right arrow on the Siri
    /// Remote. Default is a no-op for backends that don't support it.
    func setPlaybackRate(_ rate: Float)

    /// Re-bind the rendering pipeline to its current host view. Called
    /// after device rotation / foreground transitions where the layer's
    /// drawable can stop receiving frames even though the host view is
    /// still visible (audio plays, picture goes black). Default is a
    /// no-op for backends that don't need the nudge.
    func refreshDrawable()

    /// Hard-reload the current source at the current playback position.
    /// Heavier than `refreshDrawable` (audio glitches and the network
    /// stream re-buffers) but rebuilds the underlying vout entirely —
    /// the only reliable recovery on devices where rotation leaves VLC's
    /// drawable permanently black even after pause+play. Default is a
    /// no-op for backends that don't need it.
    func reloadAtCurrentPosition()

    func playbackEndEvents() -> AsyncStream<Void>

    var onTimeUpdate: ((Double) -> Void)? { get set }
    var onStateChange: (() -> Void)? { get set }
    var onPlaybackEnd: (() -> Void)? { get set }
    /// Fires when the underlying engine reports a PiP state transition.
    /// `true` on entry, `false` on exit (whether the user dismissed PiP
    /// from system controls or it ended via our `stopPiP` path). Backends
    /// without PiP support never call this.
    var onPiPStateChanged: ((Bool) -> Void)? { get set }
}

public extension PlayerBackend {
    func swapToLocalFile(_ fileURL: URL) {
        // Default no-op — backends without progressive swap ignore the call.
    }

    func refreshDrawable() {
        // Default no-op — backends with a stable drawable binding don't
        // need to do anything on rotation / foreground transitions.
    }

    func reloadAtCurrentPosition() {
        // Default no-op — backends without a vout-rebind problem don't
        // need the heavy hammer.
    }

    func setPlaybackRate(_ rate: Float) {
        // Default no-op — backends without rate control ignore the call.
    }
}
#endif
