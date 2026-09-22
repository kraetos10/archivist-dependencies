import Foundation

/// The user's chosen playback speed, shared by every video.
///
/// Stored under the key the vendored `PlaybackService` already reads when it
/// starts a media list, so each new load — a fresh video, auto-advance, the
/// swap to a cached file — picks the speed up without being told.
public enum PlaybackSpeed {
    static let storageKey = "playback-speed-custom"

    public static let options: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    /// The saved speed, or normal speed if none has been chosen.
    public static var saved: Float {
        let speed = UserDefaults.standard.float(forKey: storageKey)
        return speed > 0 ? speed : 1
    }

    static func save(_ speed: Float) {
        UserDefaults.standard.set(speed, forKey: storageKey)
    }

    /// "1×", "1.25×", "0.5×".
    public static func label(for speed: Float) -> String {
        speed.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}
