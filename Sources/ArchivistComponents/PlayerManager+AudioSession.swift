#if !os(tvOS) && !os(watchOS)
import AVFoundation
import Dependencies
import os

extension PlayerManager {
    /// Audio-session diagnostics for the Siri-announcement report, readable
    /// in Console.app from a connected device (subsystem
    /// `uk.co.wunsch.iarchivist`, category `audio-session`).
    nonisolated static let audioLog = Logger(
        subsystem: "uk.co.wunsch.iarchivist",
        category: "audio-session"
    )

    /// The system raises this hint when another app's audio (an
    /// announcement, navigation) wants the room, whether or not an
    /// interruption follows. Seeing it with no `interruption` line beside it
    /// means the session was ducked, not interrupted.
    func observeSilenceHint() {
        silenceHintObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil,
            queue: .main
        ) { notification in
            let key = AVAudioSessionSilenceSecondaryAudioHintTypeKey
            let type = notification.userInfo?[key] as? UInt
            MainActor.assumeIsolated {
                Self.audioLog.notice("silenceHint type=\(type ?? 99) \(Self.sessionSnapshot(), privacy: .public)")
            }
        }
    }

    /// Category, mode and route on one line.
    static func sessionSnapshot() -> String {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        return "[category=\(session.category.rawValue) mode=\(session.mode.rawValue) "
            + "options=\(session.categoryOptions.rawValue) policy=\(session.routeSharingPolicy.rawValue) "
            + "outputs=\(outputs) silenceHint=\(session.secondaryAudioShouldBeSilencedHint) "
            + "otherAudio=\(session.isOtherAudioPlaying)]"
    }

    func logInterruption(
        type: UInt?,
        reason: UInt?,
        options: UInt?
    ) {
        let playing = "isPlaying=\(isPlaying) backendPlaying=\(backend?.isPlaying == true)"
        Self.audioLog.notice(
            "interruption type=\(type ?? 99) reason=\(reason ?? 99) options=\(options ?? 0) \(playing)"
        )
        Self.audioLog.notice("interruption session \(Self.sessionSnapshot(), privacy: .public)")
    }

    static func logRouteChange(reason: UInt?) {
        audioLog.notice("routeChange reason=\(reason ?? 99) \(sessionSnapshot(), privacy: .public)")
    }

    func logBecomeActive(returningFromPiP: Bool) {
        let playing = isPlaying
        Self.audioLog.notice("becomeActive isPlaying=\(playing) returningFromPiP=\(returningFromPiP)")
    }

    /// Keep checking the session mode while playback runs.
    ///
    /// Neither trigger `reassertSpokenAudioMode` had was enough. A change of
    /// mode alone posts no route-change notification, and the "playback
    /// started" hook runs before VLC's audio output has set its own mode.
    /// Device logs showed `.moviePlayback` in force while a Siri
    /// announcement played over the video. Checking on a timer needs no
    /// notification; the call is a cheap no-op while the mode is right.
    func startSpokenAudioWatch() {
        guard spokenAudioWatch == nil else { return }
        spokenAudioWatch = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                reassertSpokenAudioMode()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopSpokenAudioWatch() {
        spokenAudioWatch?.cancel()
        spokenAudioWatch = nil
    }

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
        guard spokenAudioReasserts.count < 3 else {
            Self.audioLog.notice("reassert .spokenAudio skipped: capped, mode=\(session.mode.rawValue, privacy: .public)")
            return
        }
        spokenAudioReasserts.append(now)
        Self.audioLog.notice("reasserting .spokenAudio over mode=\(session.mode.rawValue, privacy: .public)")
        withErrorReporting {
            try session.setMode(.spokenAudio)
        }
    }
}
#endif
