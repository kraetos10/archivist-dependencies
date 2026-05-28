public import SQLiteData
import ArchivistNetworking
import Foundation

public struct TubeData: Sendable {
    public init() {}

    public static let shared = TubeData()

    public func appDatabase() throws -> DatabaseWriter {
        let configuration = makeConfiguration()
        let path = resolveDatabasePath()
        let database = try DatabasePool(path: path, configuration: configuration)
        try migrator().migrate(database)
        return database
    }

    /// In-memory database with the full schema applied. Intended for tests
    /// and previews where on-disk persistence is undesirable.
    public func inMemoryDatabase() throws -> DatabaseWriter {
        let database = try DatabaseQueue(configuration: makeConfiguration())
        try migrator().migrate(database)
        return database
    }

    private func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create deviceDownloads") { db in
            try #sql("""
                CREATE TABLE "deviceDownloads" (
                    "id" TEXT PRIMARY KEY NOT NULL,
                    "title" TEXT NOT NULL,
                    "channelName" TEXT NOT NULL,
                    "thumbUrl" TEXT,
                    "status" INTEGER,
                    "progress" REAL NOT NULL DEFAULT 0,
                    "fileSize" INTEGER,
                    "downloadedAt" REAL,
                    "createdAt" REAL NOT NULL
                ) STRICT
                """).execute(db)
        }

        migrator.registerMigration("Create serverConnections") { db in
            try #sql("""
                CREATE TABLE "serverConnections" (
                    "id" INTEGER PRIMARY KEY NOT NULL DEFAULT 1,
                    "serverAddress" TEXT NOT NULL DEFAULT '',
                    "port" TEXT NOT NULL DEFAULT '',
                    "useHTTP" INTEGER NOT NULL DEFAULT 0,
                    CHECK ("id" = 1)
                ) STRICT
                """).execute(db)
        }

        migrator.registerMigration("Create playNextItems") { db in
            try #sql("""
                CREATE TABLE "playNextItems" (
                    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                    "videoId" TEXT NOT NULL,
                    "title" TEXT NOT NULL,
                    "channelName" TEXT NOT NULL,
                    "thumbUrl" TEXT,
                    "duration" TEXT,
                    "addedAt" REAL NOT NULL
                ) STRICT
                """).execute(db)
        }

        return migrator
    }

    private func makeConfiguration() -> Configuration {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        return configuration
    }

    private func resolveDatabasePath() -> String {
        #if os(tvOS)
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #else
        let baseURL = URL.documentsDirectory
        #endif
        let url = baseURL.appending(component: "db.sqlite")
        return url.path
    }
}
