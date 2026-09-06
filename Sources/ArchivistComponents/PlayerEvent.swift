import Foundation

/// Playback notifications broadcast by `PlayerManager` to any interested
/// observer — typically the `VideoDetail` reducer and the CarPlay
/// coordinator, neither of which the manager can see directly.
///
/// These replace the single-assignment `onPause` / `onPlaybackCompleted` /
/// `onNextRequested` … closure slots the manager used to expose. Those were
/// last-writer-wins: with VideoDetail and CarPlay both installing an
/// `onPause`, whichever ran second silently disabled the other's
/// progress-save for the rest of the session. A broadcast stream lets every
/// observer receive every event, and lets each one filter to the video it
/// actually cares about.
///
/// Every case carries the state its handler needs. Delivery is asynchronous,
/// so an observer cannot read `PlayerManager.currentTime` when the event
/// lands — by then `stop()` has already zeroed it. Snapshotting at emit time
/// is what keeps the final progress save accurate.
public enum PlayerEvent: Sendable, Equatable {
    /// Playback stopped advancing — user pause, an external stop, or the
    /// backend reporting it fell out of the playing state. Carries the
    /// position at the moment of the pause so a late observer still saves
    /// the right value.
    case paused(videoId: String?, position: Int)

    /// The player reached end-of-media on its own, distinct from a pause or
    /// stop. Fires regardless of which UI surface is visible — notably it
    /// still fires when the detail screen has been dismissed and the video
    /// finished in PiP, which is why the watched flag has to be driven from
    /// here rather than from the screen.
    case playbackCompleted(videoId: String?)

    /// The parallel prebuffer download finished and the backend swapped to
    /// the local file.
    case cacheCompleted(videoId: String)

    /// A `load()` is about to replace whatever was playing. Emitted before
    /// the outgoing video is torn down, and carrying its position, because
    /// any UI still bound to it — the mini player above all — needs both to
    /// stand down *and* to save a resume position that `stop()` is about to
    /// zero.
    ///
    /// Fires for every load with something already playing, including a
    /// feature auto-advancing to its own next video. Tell the two apart by
    /// comparing `previousVideoId` against the video your state holds
    /// *now*: on your own advance you have already moved on, so they differ.
    case supersededByNewMedia(previousVideoId: String, position: Int, newVideoId: String?)

    /// User asked for the next video from the transport controls.
    case nextRequested

    /// User asked for the previous video from the transport controls.
    case previousRequested

    /// User tapped "play now" on the auto-play countdown card.
    case autoPlayPlayNowTapped

    /// User tapped "cancel" on the auto-play countdown card.
    case autoPlayCancelTapped
}
