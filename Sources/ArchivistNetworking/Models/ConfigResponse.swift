import Foundation

public nonisolated struct AppConfigResponse: Decodable, Sendable, Equatable {
    public let subscriptions: SubscriptionsConfig?
    public let downloads: DownloadsConfig?
    public let application: ApplicationConfig?

    public init(subscriptions: SubscriptionsConfig?, downloads: DownloadsConfig?, application: ApplicationConfig?) {
        self.subscriptions = subscriptions
        self.downloads = downloads
        self.application = application
    }
}

public nonisolated struct SubscriptionsConfig: Decodable, Sendable, Equatable {
    public let channelSize: Int?
    public let autoStart: Bool?
    public let pageSize: Int?

    public init(channelSize: Int?, autoStart: Bool?, pageSize: Int?) {
        self.channelSize = channelSize
        self.autoStart = autoStart
        self.pageSize = pageSize
    }

    enum CodingKeys: String, CodingKey {
        case channelSize = "channel_size"
        case autoStart = "auto_start"
        case pageSize = "page_size"
    }
}

public nonisolated struct DownloadsConfig: Decodable, Sendable, Equatable {
    public let format: String?
    public let formatSort: String?
    public let limitSpeed: Int?
    public let throttleRate: Int?
    public let autoDeleteDays: Int?
    public let subtitle: Bool?
    public let subtitleSource: String?
    public let subtitleLang: String?
    public let cookie: Bool?
    public let intSponsorblock: Bool?

    public init(
        format: String?,
        formatSort: String?,
        limitSpeed: Int?,
        throttleRate: Int?,
        autoDeleteDays: Int?,
        subtitle: Bool?,
        subtitleSource: String?,
        subtitleLang: String?,
        cookie: Bool?,
        intSponsorblock: Bool?
    ) {
        self.format = format
        self.formatSort = formatSort
        self.limitSpeed = limitSpeed
        self.throttleRate = throttleRate
        self.autoDeleteDays = autoDeleteDays
        self.subtitle = subtitle
        self.subtitleSource = subtitleSource
        self.subtitleLang = subtitleLang
        self.cookie = cookie
        self.intSponsorblock = intSponsorblock
    }

    enum CodingKeys: String, CodingKey {
        case format
        case formatSort = "format_sort"
        case limitSpeed = "limit_speed"
        case throttleRate = "throttle_rate"
        case autoDeleteDays = "autodelete_days"
        case subtitle
        case subtitleSource = "subtitle_source"
        case subtitleLang = "subtitle_lang"
        case cookie
        case intSponsorblock = "int_sponsorblock"
    }
}

public nonisolated struct ApplicationConfig: Decodable, Sendable, Equatable {
    public let enableSnapshot: Bool?
    public let enableCast: Bool?

    public init(enableSnapshot: Bool?, enableCast: Bool?) {
        self.enableSnapshot = enableSnapshot
        self.enableCast = enableCast
    }

    enum CodingKeys: String, CodingKey {
        case enableSnapshot = "enable_snapshot"
        case enableCast = "enable_cast"
    }
}

public nonisolated struct HealthResponse: Decodable, Sendable, Equatable {
    public let status: String?

    public init(status: String?) {
        self.status = status
    }
}

public nonisolated struct PingResponse: Decodable, Sendable, Equatable {
    public let response: String?
    public let user: Int?
    public let version: String?

    public init(response: String?, user: Int?, version: String?) {
        self.response = response
        self.user = user
        self.version = version
    }
}

public nonisolated struct RefreshResponse: Decodable, Sendable, Equatable {
    public let state: String?
    public let totalQueued: Int?

    public init(state: String?, totalQueued: Int?) {
        self.state = state
        self.totalQueued = totalQueued
    }

    enum CodingKeys: String, CodingKey {
        case state
        case totalQueued = "total_queued"
    }
}

public nonisolated struct AsyncTaskResponse: Decodable, Sendable, Equatable {
    public let taskId: String?
    public let status: String?
    public let message: String?
    public let filename: String?

    public init(taskId: String?, status: String?, message: String?, filename: String?) {
        self.taskId = taskId
        self.status = status
        self.message = message
        self.filename = filename
    }

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status
        case message
        case filename
    }
}

public nonisolated struct BackupResponse: Decodable, Sendable, Equatable {
    public let filename: String?
    public let fileSize: Int?
    public let timestamp: String?
    public let reason: String?

    public init(filename: String?, fileSize: Int?, timestamp: String?, reason: String?) {
        self.filename = filename
        self.fileSize = fileSize
        self.timestamp = timestamp
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case fileSize = "file_size"
        case timestamp
        case reason
    }
}

public nonisolated struct SnapshotResponse: Decodable, Sendable, Equatable {
    public let id: String?
    public let state: String?
    public let esVersion: String?
    public let startTime: String?
    public let endTime: String?

    public init(id: String?, state: String?, esVersion: String?, startTime: String?, endTime: String?) {
        self.id = id
        self.state = state
        self.esVersion = esVersion
        self.startTime = startTime
        self.endTime = endTime
    }

    enum CodingKeys: String, CodingKey {
        case id
        case state
        case esVersion = "es_version"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
