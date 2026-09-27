import Foundation

/// Parsing and display of the server's date strings, shared by the API
/// models and by the locally stored play-next queue, which keeps the raw
/// string so its rows can show the same "2 weeks ago" as everywhere else.
///
/// The single place dates are parsed: every model goes through here rather
/// than building its own formatter per call.
public nonisolated enum PublishedDate {
    /// Accepts an ISO 8601 date-time (with or without fractional seconds) or
    /// a bare `yyyy-MM-dd` date, which older servers send for `published`.
    public static func date(from raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if let date = try? Date(raw, strategy: .iso8601) {
            return date
        }
        if let date = try? Date(raw, strategy: fractionalSeconds) {
            return date
        }
        return try? Date(raw, strategy: dateOnly)
    }

    /// "2 weeks ago", in the reader's locale.
    public static func relative(
        from raw: String?,
        relativeTo now: Date = .now
    ) -> String? {
        guard let date = date(from: raw) else { return nil }
        return relative(date, relativeTo: now)
    }

    /// "2 weeks ago" for an already-parsed date.
    public static func relative(
        _ date: Date,
        relativeTo now: Date = .now
    ) -> String {
        Date.AnchoredRelativeFormatStyle(
            anchor: date,
            presentation: .named,
            unitsStyle: .wide
        )
        .format(now)
    }

    /// Medium date and short time, in the reader's locale.
    public static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static let fractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private static let dateOnly = Date.ISO8601FormatStyle(timeZone: .current)
        .year()
        .month()
        .day()
}
