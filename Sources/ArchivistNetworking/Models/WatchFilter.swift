import Foundation

public enum WatchFilter: String, CaseIterable, Sendable, Equatable {
    case all
    case unwatched
    case watched

    public var apiValue: String? {
        switch self {
        case .all: nil
        case .unwatched: "unwatched"
        case .watched: "watched"
        }
    }

    public var label: String {
        switch self {
        case .all: "All"
        case .unwatched: "Unwatched"
        case .watched: "Watched"
        }
    }

    public var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .unwatched: "eye.slash"
        case .watched: "eye"
        }
    }
}
