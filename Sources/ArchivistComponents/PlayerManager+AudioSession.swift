#if !os(tvOS) && !os(watchOS)
import AVFoundation
import Dependencies

extension PlayerManager {
    /// Put the session back in `.spokenAudio` after VLC changed it.
    ///
    /// VLC's iOS audio output sets the session to `.playback` /
    /// `.moviePlayback` every time it starts (`avas_SetActive` in
    /// `audiounit_ios.m`) — each video, each resume after a pause. That
    /// quietly undid `configureAudioSession`, so Siri announcements went
    /// back to ducking the video instead of interrupting it, and nothing
    /// paused. Only the mode changes; VLC's category, route sharing policy
    /// and options stay as it set them.
    ///
    /// Capped at a few a short while: if VLC ever answered a mode change by
    /// restarting its output, the two would otherwise fight in a loop.
    func reassertSpokenAudioMode() {
        let session = AVAudioSession.sharedInstance()
        guard session.category == .playback, session.mode != .spokenAudio else { return }
        let now = ContinuousClock.now
        spokenAudioReasserts.removeAll { now - $0 > .seconds(10) }
        guard spokenAudioReasserts.count < 3 else { return }
        spokenAudioReasserts.append(now)
        withErrorReporting {
            try session.setMode(.spokenAudio)
        }
    }
}
#endif
