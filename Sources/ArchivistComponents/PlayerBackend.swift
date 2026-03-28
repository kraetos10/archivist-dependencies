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
        startPosition: Double?,
        authHeaders: [String: String]
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

    func playbackEndEvents() -> AsyncStream<Void>

    var onTimeUpdate: ((Double) -> Void)? { get set }
    var onStateChange: (() -> Void)? { get set }
    var onPlaybackEnd: (() -> Void)? { get set }
}

public extension PlayerBackend {
    func swapToLocalFile(_ fileURL: URL) {
        // Default no-op — backends without progressive swap ignore the call.
    }
}
#endif
