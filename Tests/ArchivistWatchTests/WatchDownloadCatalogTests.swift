#if os(watchOS)
@testable import ArchivistWatch
import Foundation
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WatchDownloadCatalogTests {
    private func record(
        _ id: String,
        downloadedAt: Double
    ) -> WatchDownload {
        WatchDownload(
            id: id,
            title: id,
            channelName: "Channel",
            duration: 100,
            durationStr: nil,
            fileSize: 10,
            downloadedAt: downloadedAt,
            lastPlayedPosition: 0,
            thumbPath: nil
        )
    }

    private func makeCatalog(storage: WatchAudioStorage) throws -> WatchDownloadCatalog {
        let catalog = WatchDownloadCatalog()
        catalog.setup(database: try WatchData.shared.inMemoryDatabase(), storage: storage)
        return catalog
    }

    @Test func addsNewestFirstAndRemoves() throws {
        let catalog = try makeCatalog(storage: WatchFixtures.temporaryStorage())
        catalog.add(record("old", downloadedAt: 1))
        catalog.add(record("new", downloadedAt: 2))
        #expect(catalog.records.map(\.id) == ["new", "old"])

        catalog.remove(videoId: "new")
        #expect(catalog.records.map(\.id) == ["old"])
        #expect(!catalog.contains(videoId: "new"))
    }

    @Test func positionUpdatesArePersisted() throws {
        let catalog = try makeCatalog(storage: WatchFixtures.temporaryStorage())
        catalog.add(record("v1", downloadedAt: 1))
        catalog.updatePosition(videoId: "v1", position: 42)
        #expect(catalog.record(for: "v1")?.lastPlayedPosition == 42)
    }

    @Test func setupDropsRecordsWhoseFileIsGone() throws {
        let storage = WatchFixtures.temporaryStorage()
        try storage.ensureDirectoryExists()
        try Data("audio".utf8).write(to: storage.localFileURL(for: "kept"))

        let database = try WatchData.shared.inMemoryDatabase()
        let seeding = WatchDownloadCatalog()
        seeding.setup(database: database, storage: storage)
        seeding.add(record("kept", downloadedAt: 1))
        seeding.add(record("missing", downloadedAt: 2))

        let catalog = WatchDownloadCatalog()
        catalog.setup(database: database, storage: storage)
        #expect(catalog.records.map(\.id) == ["kept"])
    }

    @Test func storageMovesAFinishedDownloadIntoPlace() throws {
        let storage = WatchFixtures.temporaryStorage()
        let source = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("abc".utf8).write(to: source)

        let stored = try storage.store(downloadedFile: source, videoId: "v1")
        #expect(stored == storage.localFileURL(for: "v1"))
        #expect(storage.isDownloaded(videoId: "v1"))
        #expect(storage.fileSize(videoId: "v1") == 3)
        try storage.deleteAudio(videoId: "v1")
        #expect(!storage.isDownloaded(videoId: "v1"))
    }
}
#endif
