import Foundation

public enum WatchFilter: String, CaseIterable, Sendable, Equatable {
    case all
    case unwatched
    case watched
    case downloaded

    public var apiValue: String? {
        switch self {
        case .all, .downloaded: nil
        case .unwatched: "unwatched"
        case .watched: "watched"
        }
    }

    public var label: String {
        switch self {
        case .all: "All"
        case .unwatched: "Unwatched"
        case .watched: "Watched"
        case .downloaded: "Downloaded"
        }
    }

    public var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .unwatched: "eye.slash"
        case .watched: "eye"
        case .downloaded: "arrow.down.circle"
        }
    }
}
