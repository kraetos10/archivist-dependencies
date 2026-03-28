import ArchivistNetworking
import Dependencies
import Foundation
internal import SQLiteData
import StructuredQueries

public struct DeviceDownloadDatabase: Sendable {
    public var insertDownload: @Sendable (DeviceDownload) throws -> Void
    public var updateProgress: @Sendable (_ videoId: String, _ progress: Double) throws -> Void
    public var markCompleted: @Sendable (_ videoId: String, _ fileSize: Int?) throws -> Void
    public var markFailed: @Sendable (_ videoId: String) throws -> Void
    public var deleteDownload: @Sendable (_ videoId: String) throws -> Void
    public var deleteAll: @Sendable () throws -> Void
    public var cleanupStaleDownloads: @Sendable () throws -> Void
}

extension DeviceDownloadDatabase: DependencyKey {
    public static let liveValue: DeviceDownloadDatabase = {
        @Dependency(\.defaultDatabase) var database
        return DeviceDownloadDatabase(
            insertDownload: { download in
                try database.write { db in
                    try DeviceDownload
                        .insert {
                            download
                        } onConflict: {
                            $0.id
                        } doUpdate: { deviceDownload, excluded in
                            deviceDownload.title = excluded.title
                            deviceDownload.channelName = excluded.channelName
                            deviceDownload.thumbUrl = excluded.thumbUrl
                            deviceDownload.status = excluded.status
                            deviceDownload.progress = excluded.progress
                            deviceDownload.fileSize = excluded.fileSize
                        }
                        .execute(db)
                }
            },
            updateProgress: { videoId, progress in
                try database.write { db in
                    try DeviceDownload
                        .find(videoId)
                        .update { $0.progress = #bind(progress) }
                        .execute(db)
                }
            },
            markCompleted: { videoId, fileSize in
                try database.write { db in
                    try DeviceDownload
                        .find(videoId)
                        .update {
                            $0.status = #bind(.completed)
                            $0.progress = #bind(1)
                            $0.fileSize = #bind(fileSize)
                            $0.downloadedAt = #bind(Date().timeIntervalSince1970)
                        }
                        .execute(db)
                }
            },
            markFailed: { videoId in
                try database.write { db in
                    try DeviceDownload
                        .find(videoId)
                        .update { $0.status = #bind(.failed) }
                        .execute(db)
                }
            },
            deleteDownload: { videoId in
                try database.write { db in
                    try DeviceDownload
                        .find(videoId)
                        .delete()
                        .execute(db)
                }
            },
            deleteAll: {
                try database.write { db in
                    try DeviceDownload.delete().execute(db)
                }
            },
            cleanupStaleDownloads: {
                try database.write { db in
                    try DeviceDownload
                        .where { $0.status.eq(#bind(.downloading)) }
                        .update { $0.status = #bind(.failed) }
                        .execute(db)
                }
            }
        )
    }()

    public static let testValue = DeviceDownloadDatabase(
        insertDownload: { _ in },
        updateProgress: { _, _ in },
        markCompleted: { _, _ in },
        markFailed: { _ in },
        deleteDownload: { _ in },
        deleteAll: { },
        cleanupStaleDownloads: { }
    )
}

extension DependencyValues {
    public var deviceDownloadDatabase: DeviceDownloadDatabase {
        get { self[DeviceDownloadDatabase.self] }
        set { self[DeviceDownloadDatabase.self] = newValue }
    }
}
