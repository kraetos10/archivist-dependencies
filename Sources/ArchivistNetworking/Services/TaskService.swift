import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct TaskService: Sendable {
    public var getTaskById: @Sendable (
        _ config: ServerConfig,
        _ taskId: String
    ) async throws -> TaskResponse
    public var sendTaskCommand: @Sendable (
        _ config: ServerConfig,
        _ taskId: String,
        _ command: String
    ) async throws -> Void
    public var getAllTaskResults: @Sendable (
        _ config: ServerConfig
    ) async throws -> [String: TaskResult]
    public var getTaskResult: @Sendable (
        _ config: ServerConfig,
        _ name: String
    ) async throws -> TaskResult
    public var startTask: @Sendable (
        _ config: ServerConfig,
        _ name: String
    ) async throws -> TaskResponse
    public var getDownloadNotifications: @Sendable (
        _ config: ServerConfig
    ) async throws -> [NotificationResponse]
    public var getNotifications: @Sendable (
        _ config: ServerConfig
    ) async throws -> [TaskNotification]
    public var getSchedules: @Sendable (
        _ config: ServerConfig
    ) async throws -> [String: TaskScheduleResponse]
    public var getSchedule: @Sendable (
        _ config: ServerConfig,
        _ name: String
    ) async throws -> TaskScheduleResponse
    public var updateSchedule: @Sendable (
        _ config: ServerConfig,
        _ name: String,
        _ schedule: TaskScheduleRequest
    ) async throws -> Void
    public var deleteSchedule: @Sendable (
        _ config: ServerConfig,
        _ name: String
    ) async throws -> Void
}

extension TaskService: DependencyKey {
    public static let liveValue = TaskService(
        getTaskById: { config, taskId in
            let request = NetworkAPIRequest<TaskResponse>(config: config, path: .taskById(id: taskId))
            return try await request.execute().data
        },
        sendTaskCommand: { config, taskId, command in
            let body = try JSONEncoder().encode(TaskCommandRequest(command: command))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .taskById(id: taskId),
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        getAllTaskResults: { config in
            let request = NetworkAPIRequest<[String: TaskResult]>(config: config, path: .taskByName)
            return try await request.execute().data
        },
        getTaskResult: { config, name in
            let request = NetworkAPIRequest<TaskResult>(config: config, path: .taskByNameSpecific(name: name))
            return try await request.execute().data
        },
        startTask: { config, name in
            let request = NetworkAPIRequest<TaskResponse>(
                config: config,
                path: .taskByNameSpecific(name: name),
                method: .post
            )
            return try await request.execute().data
        },
        getDownloadNotifications: { config in
            let request = NetworkAPIRequest<[NotificationResponse]>(
                config: config,
                path: .notification,
                queryItems: [URLQueryItem(name: "filter", value: "download")]
            )
            return try await request.execute().data
        },
        getNotifications: { config in
            let request = NetworkAPIRequest<[TaskNotification]>(config: config, path: .taskNotification)
            return try await request.execute().data
        },
        getSchedules: { config in
            let request = NetworkAPIRequest<[String: TaskScheduleResponse]>(config: config, path: .taskSchedule)
            return try await request.execute().data
        },
        getSchedule: { config, name in
            let request = NetworkAPIRequest<TaskScheduleResponse>(config: config, path: .taskScheduleSpecific(name: name))
            return try await request.execute().data
        },
        updateSchedule: { config, name, schedule in
            let body = try JSONEncoder().encode(schedule)
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .taskScheduleSpecific(name: name),
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        deleteSchedule: { config, name in
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .taskScheduleSpecific(name: name),
                method: .delete
            )
            _ = try await request.execute()
        }
    )

    public static var testValue: TaskService { TaskService() }
}
