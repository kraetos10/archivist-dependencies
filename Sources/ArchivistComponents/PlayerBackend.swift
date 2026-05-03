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

    /// Re-bind the rendering pipeline to its current host view. Called
    /// after device rotation / foreground transitions where the layer's
    /// drawable can stop receiving frames even though the host view is
    /// still visible (audio plays, picture goes black). Default is a
    /// no-op for backends that don't need the nudge.
    func refreshDrawable()

    func playbackEndEvents() -> AsyncStream<Void>

    var onTimeUpdate: ((Double) -> Void)? { get set }
    var onStateChange: (() -> Void)? { get set }
    var onPlaybackEnd: (() -> Void)? { get set }
}

public extension PlayerBackend {
    func swapToLocalFile(_ fileURL: URL) {
        // Default no-op — backends without progressive swap ignore the call.
    }

    func refreshDrawable() {
        // Default no-op — backends with a stable drawable binding don't
        // need to do anything on rotation / foreground transitions.
    }
}
#endif
