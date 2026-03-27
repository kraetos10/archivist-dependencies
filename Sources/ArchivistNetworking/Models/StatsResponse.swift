import Foundation

public nonisolated struct VideoStatsResponse: Decodable, Sendable, Equatable {
    public let docCount: Int?
    public let totalDuration: Int?
    public let totalSize: Int?
    public let activeTrue: Int?
    public let activeFalse: Int?
    public let typeVideos: Int?
    public let typeStreams: Int?
    public let typeShorts: Int?

    public init(
        docCount: Int?, totalDuration: Int?, totalSize: Int?,
        activeTrue: Int?, activeFalse: Int?,
        typeVideos: Int?, typeStreams: Int?, typeShorts: Int?
    ) {
        self.docCount = docCount
        self.totalDuration = totalDuration
        self.totalSize = totalSize
        self.activeTrue = activeTrue
        self.activeFalse = activeFalse
        self.typeVideos = typeVideos
        self.typeStreams = typeStreams
        self.typeShorts = typeShorts
    }

    enum CodingKeys: String, CodingKey {
        case docCount = "doc_count"
        case totalDuration = "total_duration"
        case totalSize = "total_size"
        case activeTrue = "active_true"
        case activeFalse = "active_false"
        case typeVideos = "type_videos"
        case typeStreams = "type_streams"
        case typeShorts = "type_shorts"
    }
}

public nonisolated struct ChannelStatsResponse: Decodable, Sendable, Equatable {
    public let docCount: Int?
    public let activeTrue: Int?
    public let activeFalse: Int?
    public let subscribedTrue: Int?
    public let subscribedFalse: Int?

    public init(docCount: Int?, activeTrue: Int?, activeFalse: Int?, subscribedTrue: Int?, subscribedFalse: Int?) {
        self.docCount = docCount
        self.activeTrue = activeTrue
        self.activeFalse = activeFalse
        self.subscribedTrue = subscribedTrue
        self.subscribedFalse = subscribedFalse
    }

    enum CodingKeys: String, CodingKey {
        case docCount = "doc_count"
        case activeTrue = "active_true"
        case activeFalse = "active_false"
        case subscribedTrue = "subscribed_true"
        case subscribedFalse = "subscribed_false"
    }
}

public nonisolated struct PlaylistStatsResponse: Decodable, Sendable, Equatable {
    public let docCount: Int?
    public let activeTrue: Int?
    public let activeFalse: Int?
    public let subscribedTrue: Int?
    public let subscribedFalse: Int?

    public init(docCount: Int?, activeTrue: Int?, activeFalse: Int?, subscribedTrue: Int?, subscribedFalse: Int?) {
        self.docCount = docCount
        self.activeTrue = activeTrue
        self.activeFalse = activeFalse
        self.subscribedTrue = subscribedTrue
        self.subscribedFalse = subscribedFalse
    }

    enum CodingKeys: String, CodingKey {
        case docCount = "doc_count"
        case activeTrue = "active_true"
        case activeFalse = "active_false"
        case subscribedTrue = "subscribed_true"
        case subscribedFalse = "subscribed_false"
    }
}

public nonisolated struct DownloadStatsResponse: Decodable, Sendable, Equatable {
    public let pending: Int?
    public let ignore: Int?
    public let pendingVideos: Int?
    public let pendingShorts: Int?
    public let pendingStreams: Int?

    public init(pending: Int?, ignore: Int?, pendingVideos: Int?, pendingShorts: Int?, pendingStreams: Int?) {
        self.pending = pending
        self.ignore = ignore
        self.pendingVideos = pendingVideos
        self.pendingShorts = pendingShorts
        self.pendingStreams = pendingStreams
    }

    enum CodingKeys: String, CodingKey {
        case pending
        case ignore
        case pendingVideos = "pending_videos"
        case pendingShorts = "pending_shorts"
        case pendingStreams = "pending_streams"
    }
}

public nonisolated struct WatchStatsResponse: Decodable, Sendable, Equatable {
    public let watched: Int?
    public let unwatched: Int?
    public let continueWatching: Int?

    public init(watched: Int?, unwatched: Int?, continueWatching: Int?) {
        self.watched = watched
        self.unwatched = unwatched
        self.continueWatching = continueWatching
    }

    enum CodingKeys: String, CodingKey {
        case watched
        case unwatched
        case continueWatching = "continue"
    }
}

public nonisolated struct BiggestChannelResponse: Decodable, Sendable, Equatable, Identifiable {
    public let id: String?
    public let name: String?
    public let docCount: Int?

    public init(id: String?, name: String?, docCount: Int?) {
        self.id = id
        self.name = name
        self.docCount = docCount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case docCount = "doc_count"
    }
}

public nonisolated struct DownloadHistResponse: Decodable, Sendable, Equatable {
    public let date: String?
    public let count: Int?

    public init(date: String?, count: Int?) {
        self.date = date
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case date
        case count
    }
}
