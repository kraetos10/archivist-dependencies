import Foundation

/// Shared duration formatting, so every "time left" reads the same.
public nonisolated enum DurationText {
    /// Hours and minutes, abbreviated ("1 hr, 5 min"); under a minute reads
    /// as "0 min" rather than an empty string.
    public static func abbreviated(seconds: Int) -> String {
        Duration.seconds(max(seconds, 0)).formatted(
            .units(
                allowed: [.hours, .minutes],
                width: .abbreviated,
                zeroValueUnits: .hide,
                fractionalPart: .hide(rounded: .down)
            )
        )
    }

    /// A clock-style position ("4:05", or "1:02:03" past the hour).
    public static func clock(seconds: Double) -> String {
        let whole = Int(max(seconds.isFinite ? seconds : 0, 0))
        let pattern: Duration.TimeFormatStyle.Pattern = whole >= 3600
            ? .hourMinuteSecond
            : .minuteSecond
        return Duration.seconds(whole).formatted(.time(pattern: pattern))
    }
}
