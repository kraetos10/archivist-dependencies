#if os(tvOS)
import UIKit

extension PlayerManager {
    /// Holds the Apple TV screensaver off only while a video is playing.
    ///
    /// libvlc keeps its own screen-sleep inhibitor (`uikit_inhibit`) on for as
    /// long as the video output exists, and doesn't let go on a pause — so a
    /// paused video kept the TV awake for good. Setting the idle timer from
    /// the play state hands the screensaver back while paused, and takes it
    /// again on play.
    func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = isPlaying
    }

    /// Pause when the app leaves the foreground. The audio session is
    /// `.playback`, so a video kept playing its sound behind the Home screen
    /// after the user pressed Home. Pausing also saves the position.
    func observeBackgrounding() {
        backgroundPauseObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return }
                self.pause()
            }
        }
    }
}
#else
extension PlayerManager {
    /// Only Apple TV hands the screensaver back on pause.
    func updateIdleTimer() {}
}
#endif
