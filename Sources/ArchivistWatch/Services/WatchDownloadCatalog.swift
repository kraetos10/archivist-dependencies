#if os(watchOS)
import Foundation
import SQLiteData
import StructuredQueries

@MainActor
@Observable
public final class WatchDownloadCatalog {
    public static let shared = WatchDownloadCatalog()

    public var records: [WatchDownload] = []

    private var database: DatabaseWriter?

    public init() {}

    public func setup(database: DatabaseWriter) {
        self.database = database
        loadAll()
    }

    public func add(_ record: WatchDownload) {
        guard let database else { return }
        do {
            try database.write { db in
                try WatchDownload.upsert { record }.execute(db)
            }
            loadAll()
        } catch {}
    }

    public func remove(videoId: String) {
        guard let database else { return }
        do {
            try database.write { db in
                try WatchDownload
                    .delete()
                    .where { $0.id.eq(videoId) }
                    .execute(db)
            }
            loadAll()
        } catch {}
    }

    public func updatePosition(
        videoId: String,
        position: Double
    ) {
        guard let database else { return }
        do {
            try database.write { db in
                try WatchDownload
                    .update { $0.lastPlayedPosition = position }
                    .where { $0.id.eq(videoId) }
                    .execute(db)
            }
            if let index = records.firstIndex(where: { $0.id == videoId }) {
                records[index].lastPlayedPosition = position
            }
        } catch {}
    }

    public func record(for videoId: String) -> WatchDownload? {
        records.first { $0.id == videoId }
    }

    // MARK: - Private

    private func loadAll() {
        guard let database else { return }
        do {
            records = try database.read { db in
                try WatchDownload
                    .order { $0.downloadedAt.desc() }
                    .fetchAll(db)
            }
        } catch {}
    }
}
#endif
