import Foundation

public nonisolated struct TaskResponse: Decodable, Sendable, Equatable, Identifiable {
    public let taskId: String
    public let name: String?
    public let status: String?
    public let progress: Int?
    public let messages: [String]?
    public let command: String?
    public let totalQueued: Int?
    public let state: String?

    public var id: String { taskId }

    public init(
        taskId: String, name: String?, status: String?, progress: Int?,
        messages: [String]?, command: String?, totalQueued: Int?, state: String?
    ) {
        self.taskId = taskId
        self.name = name
        self.status = status
        self.progress = progress
        self.messages = messages
        self.command = command
        self.totalQueued = totalQueued
        self.state = state
    }

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case name
        case status
        case progress
        case messages
        case command
        case totalQueued = "total_queued"
        case state
    }
}

public nonisolated struct TaskNameResponse: Decodable, Sendable, Equatable {
    public let tasks: [String: TaskResult]?

    public init(tasks: [String: TaskResult]?) {
        self.tasks = tasks
    }
}

public nonisolated struct TaskResult: Decodable, Sendable, Equatable {
    public let status: String?
    public let result: String?
    public let dateDone: String?
    public let name: String?

    public init(status: String?, result: String?, dateDone: String?, name: String?) {
        self.status = status
        self.result = result
        self.dateDone = dateDone
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case status
        case result
        case dateDone = "date_done"
        case name
    }
}

public nonisolated struct TaskNotification: Decodable, Sendable, Equatable {
    public let taskId: String?
    public let title: String?
    public let group: String?
    public let url: String?

    public init(taskId: String?, title: String?, group: String?, url: String?) {
        self.taskId = taskId
        self.title = title
        self.group = group
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case title
        case group
        case url
    }
}

public nonisolated struct NotificationResponse: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String?
    public let group: String?
    public let level: String?
    public let messages: [String]?
    public let progress: Double?
    public let command: String?

    public init(
        id: String, title: String?, group: String?, level: String?,
        messages: [String]?, progress: Double?, command: String?
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.level = level
        self.messages = messages
        self.progress = progress
        self.command = command
    }
}

public nonisolated struct TaskScheduleResponse: Decodable, Sendable, Equatable {
    public let schedule: String?
    public let config: [String: String]?

    public init(schedule: String?, config: [String: String]?) {
        self.schedule = schedule
        self.config = config
    }

    enum CodingKeys: String, CodingKey {
        case schedule
        case config
    }
}

public nonisolated enum TaskName: String, Sendable {
    case updateSubscribed = "update_subscribed"
    case downloadPending = "download_pending"
    case extractDownload = "extract_download"
    case checkReindex = "check_reindex"
    case manualImport = "manual_import"
    case runBackup = "run_backup"
    case restoreBackup = "restore_backup"
    case rescanFilesystem = "rescan_filesystem"
    case thumbnailCheck = "thumbnail_check"
    case resyncMetadata = "resync_metadata"
    case indexPlaylists = "index_playlists"
    case subscribeTo = "subscribe_to"
    case versionCheck = "version_check"
}
