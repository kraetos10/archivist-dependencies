import Foundation

public enum WatchFilter: String, CaseIterable, Sendable, Equatable {
    case all
    case unwatched
    case continueWatching
    case watched
    case downloaded

    public var apiValue: String? {
        switch self {
        case .all, .downloaded, .continueWatching: nil
        case .unwatched: "unwatched"
        case .watched: "watched"
        }
    }

    public var label: String {
        switch self {
        case .all: String(localized: "All")
        case .unwatched: String(localized: "Unwatched")
        case .continueWatching: String(localized: "Continue Watching")
        case .watched: String(localized: "Watched")
        case .downloaded: String(localized: "On Device")
        }
    }

    public var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .unwatched: "eye.slash"
        case .continueWatching: "play.circle"
        case .watched: "eye"
        case .downloaded: "iphone"
        }
    }
}
