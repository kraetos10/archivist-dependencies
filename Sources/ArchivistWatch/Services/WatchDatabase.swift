#if os(watchOS)
import Foundation
import SQLiteData

public struct WatchData: Sendable {
    public static let shared = WatchData()

    public init() {}

    public func appDatabase() throws -> DatabaseWriter {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true

        let baseURL = URL.documentsDirectory
        let url = baseURL.appending(component: "watch_db.sqlite")
        let database = try DatabasePool(path: url.path, configuration: configuration)

        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("Create watchDownloads") { db in
            try #sql("""
                CREATE TABLE "watchDownloads" (
                    "id" TEXT PRIMARY KEY NOT NULL,
                    "title" TEXT NOT NULL,
                    "channelName" TEXT NOT NULL,
                    "duration" INTEGER,
                    "fileSize" INTEGER,
                    "downloadedAt" REAL NOT NULL,
                    "lastPlayedPosition" REAL NOT NULL DEFAULT 0
                ) STRICT
                """).execute(db)
        }

        migrator.registerMigration("Add thumbPath to watchDownloads") { db in
            try #sql("""
                ALTER TABLE "watchDownloads" ADD COLUMN "thumbPath" TEXT
                """).execute(db)
        }

        migrator.registerMigration("Add durationStr to watchDownloads") { db in
            try #sql("""
                ALTER TABLE "watchDownloads" ADD COLUMN "durationStr" TEXT
                """).execute(db)
        }

        try migrator.migrate(database)

        return database
    }
}
#endif
