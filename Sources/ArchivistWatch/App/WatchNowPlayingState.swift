#if os(watchOS)
import Foundation

@MainActor
@Observable
public final class WatchNowPlayingState {
    public private(set) var activePlayer: WatchAudioPlayerViewModel?

    /// The player handed to the most recently presented Now Playing screen.
    /// Not observed: it changes while a navigation destination is being built.
    @ObservationIgnored private var presentedPlayer: WatchAudioPlayerViewModel?

    public var isPlaying: Bool {
        activePlayer?.isPlaying ?? false
    }

    public var hasActiveSession: Bool {
        activePlayer != nil
    }

    public init() {}

    /// Returns the player for `videoId`, reusing the live one. A navigation
    /// destination is rebuilt every time the screen presenting it re-renders,
    /// so building a player there would restart playback and take over the
    /// system Now Playing card. Only one player exists at a time — the one it
    /// replaces is torn down so it gives up the shared remote commands.
    public func player(
        for videoId: String,
        make: () -> WatchAudioPlayerViewModel
    ) -> WatchAudioPlayerViewModel {
        if let presentedPlayer, presentedPlayer.videoId == videoId {
            return presentedPlayer
        }
        if let activePlayer, activePlayer.videoId == videoId {
            presentedPlayer = activePlayer
            return activePlayer
        }
        presentedPlayer?.teardown()
        let player = make()
        presentedPlayer = player
        return player
    }

    public func setPlayer(_ player: WatchAudioPlayerViewModel) {
        if let activePlayer, activePlayer !== player {
            activePlayer.teardown()
        }
        activePlayer = player
    }

    public func isActive(_ player: WatchAudioPlayerViewModel) -> Bool {
        activePlayer === player
    }

    public func clearIfMatching(_ player: WatchAudioPlayerViewModel) {
        if activePlayer === player {
            activePlayer = nil
        }
        if presentedPlayer === player {
            presentedPlayer = nil
        }
    }
}
#endif
