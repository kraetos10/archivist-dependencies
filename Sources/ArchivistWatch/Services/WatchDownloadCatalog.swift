#if os(watchOS)
import Foundation
import IssueReporting
import SQLiteData

/// The downloaded-audio records, mirrored from the `watchDownloads` table so
/// views observe them without their own queries.
@MainActor
@Observable
public final class WatchDownloadCatalog {
    public private(set) var records: [WatchDownload] = []

    @ObservationIgnored private var database: (any DatabaseWriter)?

    public init() {}

    /// Connects the database and drops records whose audio file has gone
    /// (removed by the system or a failed move), so the list only shows
    /// what can actually play.
    public func setup(
        database: any DatabaseWriter,
        storage: WatchAudioStorage
    ) {
        self.database = database
        loadAll()
        let missing = records.filter { !storage.isDownloaded(videoId: $0.id) }.map(\.id)
        guard !missing.isEmpty else { return }
        withErrorReporting {
            try database.write { db in
                try WatchDownload
                    .where { $0.id.in(missing) }
                    .delete()
                    .execute(db)
            }
        }
        loadAll()
    }

    public func add(_ record: WatchDownload) {
        guard let database else {
            reportIssue("WatchDownloadCatalog used before setup(database:storage:)")
            return
        }
        withErrorReporting {
            try database.write { db in
                try WatchDownload.upsert { record }.execute(db)
            }
        }
        loadAll()
    }

    public func remove(videoId: String) {
        guard let database else { return }
        withErrorReporting {
            try database.write { db in
                try WatchDownload.find(videoId).delete().execute(db)
            }
        }
        loadAll()
    }

    public func updatePosition(
        videoId: String,
        position: Double
    ) {
        guard let database else { return }
        withErrorReporting {
            try database.write { db in
                try WatchDownload
                    .find(videoId)
                    .update { $0.lastPlayedPosition = position }
                    .execute(db)
            }
        }
        if let index = records.firstIndex(where: { $0.id == videoId }) {
            records[index].lastPlayedPosition = position
        }
    }

    public func record(for videoId: String) -> WatchDownload? {
        records.first { $0.id == videoId }
    }

    public func contains(videoId: String) -> Bool {
        record(for: videoId) != nil
    }

    private func loadAll() {
        guard let database else { return }
        records = withErrorReporting {
            try database.read { db in
                try WatchDownload
                    .order { $0.downloadedAt.desc() }
                    .fetchAll(db)
            }
        } ?? records
    }
}
#endif
