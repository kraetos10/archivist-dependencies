#if os(watchOS)
import Foundation

@MainActor
@Observable
public final class WatchNowPlayingState {
    public static let shared = WatchNowPlayingState()

    public var activePlayer: WatchAudioPlayerViewModel?

    public var isPlaying: Bool {
        activePlayer?.isPlaying ?? false
    }

    public var hasActiveSession: Bool {
        activePlayer != nil
    }

    public init() {}

    public func setPlayer(_ player: WatchAudioPlayerViewModel) {
        activePlayer = player
    }

    public func clearIfMatching(_ player: WatchAudioPlayerViewModel) {
        if activePlayer === player {
            activePlayer = nil
        }
    }
}
#endif
