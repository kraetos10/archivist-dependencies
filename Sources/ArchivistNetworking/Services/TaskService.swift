import Foundation

public nonisolated protocol TaskServiceType: Sendable {
    func getTaskById(
        config: ServerConfig,
        taskId: String
    ) async throws -> TaskResponse
    func sendTaskCommand(
        config: ServerConfig,
        taskId: String,
        command: String
    ) async throws
    func getAllTaskResults(config: ServerConfig) async throws -> [String: TaskResult]
    func getTaskResult(
        config: ServerConfig,
        name: String
    ) async throws -> TaskResult
    func startTask(
        config: ServerConfig,
        name: String
    ) async throws -> TaskResponse
    func getDownloadNotifications(config: ServerConfig) async throws -> [NotificationResponse]
    func getNotifications(config: ServerConfig) async throws -> [TaskNotification]
    func getSchedules(config: ServerConfig) async throws -> [String: TaskScheduleResponse]
    func getSchedule(
        config: ServerConfig,
        name: String
    ) async throws -> TaskScheduleResponse
    func updateSchedule(
        config: ServerConfig,
        name: String,
        schedule: TaskScheduleRequest
    ) async throws
    func deleteSchedule(
        config: ServerConfig,
        name: String
    ) async throws
}

public nonisolated struct TaskService: TaskServiceType {
    public init() {}

    public func getTaskById(
        config: ServerConfig,
        taskId: String
    ) async throws -> TaskResponse {
        let request = NetworkAPIRequest<TaskResponse>(config: config, path: .taskById(id: taskId))
        return try await request.execute().data
    }

    public func sendTaskCommand(
        config: ServerConfig,
        taskId: String,
        command: String
    ) async throws {
        let body = try JSONEncoder().encode(TaskCommandRequest(command: command))
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .taskById(id: taskId),
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func getAllTaskResults(config: ServerConfig) async throws -> [String: TaskResult] {
        let request = NetworkAPIRequest<[String: TaskResult]>(config: config, path: .taskByName)
        return try await request.execute().data
    }

    public func getTaskResult(
        config: ServerConfig,
        name: String
    ) async throws -> TaskResult {
        let request = NetworkAPIRequest<TaskResult>(config: config, path: .taskByNameSpecific(name: name))
        return try await request.execute().data
    }

    public func startTask(
        config: ServerConfig,
        name: String
    ) async throws -> TaskResponse {
        let request = NetworkAPIRequest<TaskResponse>(
            config: config,
            path: .taskByNameSpecific(name: name),
            method: .post
        )
        return try await request.execute().data
    }

    public func getDownloadNotifications(config: ServerConfig) async throws -> [NotificationResponse] {
        let request = NetworkAPIRequest<[NotificationResponse]>(
            config: config,
            path: .notification,
            queryItems: [URLQueryItem(name: "filter", value: "download")]
        )
        return try await request.execute().data
    }

    public func getNotifications(config: ServerConfig) async throws -> [TaskNotification] {
        let request = NetworkAPIRequest<[TaskNotification]>(config: config, path: .taskNotification)
        return try await request.execute().data
    }

    public func getSchedules(config: ServerConfig) async throws -> [String: TaskScheduleResponse] {
        let request = NetworkAPIRequest<[String: TaskScheduleResponse]>(config: config, path: .taskSchedule)
        return try await request.execute().data
    }

    public func getSchedule(
        config: ServerConfig,
        name: String
    ) async throws -> TaskScheduleResponse {
        let request = NetworkAPIRequest<TaskScheduleResponse>(config: config, path: .taskScheduleSpecific(name: name))
        return try await request.execute().data
    }

    public func updateSchedule(
        config: ServerConfig,
        name: String,
        schedule: TaskScheduleRequest
    ) async throws {
        let body = try JSONEncoder().encode(schedule)
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .taskScheduleSpecific(name: name),
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func deleteSchedule(
        config: ServerConfig,
        name: String
    ) async throws {
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .taskScheduleSpecific(name: name),
            method: .delete
        )
        _ = try await request.execute()
    }
}
