import Foundation

public enum VideoSortOrder: String, CaseIterable, Sendable, Equatable {
    case published
    case downloaded
    case views
    case likes
    case duration
    case mediasize

    public var apiValue: String { rawValue }

    public var label: String {
        switch self {
        case .published: String(localized: "Published")
        case .downloaded: String(localized: "Archived")
        case .views: String(localized: "Views")
        case .likes: String(localized: "Likes")
        case .duration: String(localized: "Duration")
        case .mediasize: String(localized: "File Size")
        }
    }

    public var icon: String {
        switch self {
        case .published: "calendar"
        case .downloaded: "arrow.down.circle"
        case .views: "eye"
        case .likes: "hand.thumbsup"
        case .duration: "clock"
        case .mediasize: "internaldrive"
        }
    }
}
