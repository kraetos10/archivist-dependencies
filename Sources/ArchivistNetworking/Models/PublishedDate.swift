import Foundation

/// Parsing and display of a video's `published` string, shared by the API
/// models and by the locally stored play-next queue, which keeps the raw
/// string so its rows can show the same "2 weeks ago" as everywhere else.
public enum PublishedDate {
    public static func date(from raw: String?) -> Date? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) {
            return date
        }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        return dateOnly.date(from: raw)
    }

    /// "2 weeks ago", in the reader's locale.
    public static func relative(from raw: String?, relativeTo now: Date = Date()) -> String? {
        guard let date = date(from: raw) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
