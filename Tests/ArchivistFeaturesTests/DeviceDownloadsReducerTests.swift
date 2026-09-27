#if os(iOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(
    .serialized,
    .timeLimit(.minutes(1)),
    .dependencies {
        try $0.bootstrapInMemoryDatabase()
        $0.date.now = Date(timeIntervalSince1970: 1_000)
    }
)
struct DeviceDownloadsReducerTests {
    let config = TestFixtures.serverConfig

    private func failedDownload(_ id: String = "video_1") -> DeviceDownload {
        DeviceDownload(
            id: id,
            title: "Test Video 1",
            channelName: "Test Channel 1",
            thumbUrl: nil,
            status: .failed,
            progress: 0.4,
            fileSize: nil,
            downloadedAt: nil,
            createdAt: 0
        )
    }

    // MARK: - Storage

    /// Storage is read on appear and then every three seconds, until the
    /// screen goes away.
    @Test func storageIsPolledWhileTheScreenIsUp() async {
        let clock = TestClock()
        let reads = LockIsolated(0)
        let store = TestStore(initialState: DeviceDownloadsReducer.State(serverConfig: config)) {
            DeviceDownloadsReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.deviceStorage.usage = {
                let count = reads.withValue { $0 += 1; return $0 }
                return StorageUsage(downloadsSize: Int64(count) * 100, available: 1_000)
            }
        }

        await store.send(.view(.viewDidAppear))
        await store.receive(\.storageInfoLoaded) {
            $0.storage = StorageUsage(downloadsSize: 100, available: 1_000)
        }
        #expect(store.state.downloadsFraction == 100.0 / 1_100.0)

        await clock.advance(by: .seconds(3))
        await store.receive(\.storageInfoLoaded) {
            $0.storage = StorageUsage(downloadsSize: 200, available: 1_000)
        }

        await store.send(.view(.viewDidDisappear))
        await clock.advance(by: .seconds(30))
        #expect(reads.value == 2)
    }

    @Test func emptyStorageHasNoFraction() {
        let state = DeviceDownloadsReducer.State(serverConfig: config)

        #expect(state.downloadsFraction == nil)
    }

    // MARK: - Delete

    @Test func deletingRemovesTheFileAndRowThenRereadsStorage() async {
        let deletedFiles = LockIsolated<[String]>([])
        let deletedRows = LockIsolated<[String]>([])
        let store = TestStore(initialState: DeviceDownloadsReducer.State(serverConfig: config)) {
            DeviceDownloadsReducer()
        } withDependencies: {
            $0.localVideoStorage.deleteVideo = { id in deletedFiles.withValue { $0.append(id) } }
            $0.deviceDownloadDatabase.deleteDownload = { id in deletedRows.withValue { $0.append(id) } }
            $0.deviceStorage.usage = { StorageUsage(downloadsSize: 0, available: 500) }
        }

        await store.send(.view(.deleteTapped("video_1")))
        await store.receive(\.storageInfoLoaded) {
            $0.storage = StorageUsage(downloadsSize: 0, available: 500)
        }
        #expect(deletedFiles.value == ["video_1"])
        #expect(deletedRows.value == ["video_1"])
    }

    @Test func aFailedDeleteSaysSoAndKeepsTheRow() async {
        let failure = CocoaError(.fileWriteNoPermission)
        let deletedRows = LockIsolated<[String]>([])
        let store = TestStore(initialState: DeviceDownloadsReducer.State(serverConfig: config)) {
            DeviceDownloadsReducer()
        } withDependencies: {
            $0.localVideoStorage.deleteVideo = { _ in throw failure }
            $0.deviceDownloadDatabase.deleteDownload = { id in deletedRows.withValue { $0.append(id) } }
            $0.deviceStorage.usage = { StorageUsage(downloadsSize: 10, available: 500) }
        }

        await store.send(.view(.deleteTapped("video_1")))
        await store.receive(\.operationFailed) {
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(failure.localizedDescription)
            }
        }
        await store.receive(\.storageInfoLoaded) {
            $0.storage = StorageUsage(downloadsSize: 10, available: 500)
        }
        #expect(deletedRows.value.isEmpty)
    }

    // MARK: - Retry

    /// Tapping a failed download fetches the video again, re-inserts the
    /// row as downloading and restarts the transfer.
    @Test func tappingAFailedDownloadRetriesIt() async {
        let inserted = LockIsolated<[DeviceDownload]>([])
        let manager = RecordingDownloadManager()
        let store = TestStore(initialState: DeviceDownloadsReducer.State(serverConfig: config)) {
            DeviceDownloadsReducer()
        } withDependencies: {
            $0.videoService.getVideo = { _, _ in TestFixtures.downloadableVideo }
            $0.deviceDownloadDatabase.insertDownload = { row in inserted.withValue { $0.append(row) } }
            $0.persistentDownloadManager = manager
        }

        await store.send(.view(.downloadTapped(failedDownload())))
        await store.finish()

        #expect(inserted.value.map(\.id) == ["video_1"])
        #expect(inserted.value.first?.status == .downloading)
        #expect(inserted.value.first?.createdAt == 1_000)
        #expect(await manager.started == ["video_1"])
    }

    @Test func aRetryWithoutServerMediaSaysSo() async {
        let store = TestStore(initialState: DeviceDownloadsReducer.State(serverConfig: config)) {
            DeviceDownloadsReducer()
        } withDependencies: {
            // `video1` has no media path on the server.
            $0.videoService.getVideo = { _, _ in TestFixtures.video1 }
        }

        await store.send(.view(.downloadTapped(failedDownload())))
        await store.receive(\.operationFailed) {
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(String.localised("video.download.unavailable", table: .videos))
            }
        }
    }

    @Test func aFailedRetrySaysSo() async {
        let failure = URLError(.notConnectedToInternet)
        let store = TestStore(initialState: DeviceDownloadsReducer.State(serverConfig: config)) {
            DeviceDownloadsReducer()
        } withDependencies: {
            $0.videoService.getVideo = { _, _ in throw failure }
        }

        await store.send(.view(.downloadTapped(failedDownload())))
        await store.receive(\.operationFailed) {
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(failure.localizedDescription)
            }
        }
    }

    @Test func addToPlaylistOpensThePicker() async {
        let store = TestStore(initialState: DeviceDownloadsReducer.State(serverConfig: config)) {
            DeviceDownloadsReducer()
        }

        await store.send(.view(.addToPlaylistTapped(failedDownload()))) {
            $0.playlistPicker = PlaylistPickerReducer.State(serverConfig: config, videoId: "video_1")
        }
    }
}

/// Records the downloads it was asked to start; never runs one.
private actor RecordingDownloadManager: PersistentDownloadManagerType {
    private(set) var started: [String] = []

    func startDownload(
        url: URL,
        videoId: String,
        title: String,
        expectedSize: Int64?,
        authHeaders: [String: String],
        thumbnailURL: URL?
    ) async {
        started.append(videoId)
    }

    func isDownloading(videoId: String) async -> Bool { false }

    func progress(for videoId: String) async -> Double { 0 }

    func observe(videoId: String) async -> AsyncStream<DownloadEvent> {
        AsyncStream { $0.finish() }
    }

    func activeDownloads() async -> [DeviceDownloadInfo] { [] }
}

private extension TestFixtures {
    /// `video1` with a server media path, so it can be downloaded.
    static let downloadableVideo = VideoResponse(
        videoId: video1.videoId,
        title: video1.title,
        description: nil,
        category: nil,
        channel: video1.channel,
        published: video1.published,
        dateDownloaded: nil,
        vidLastRefresh: nil,
        vidThumbUrl: nil,
        vidType: nil,
        active: nil,
        mediaUrl: "/media/video_1.mp4",
        mediaSize: 2_048,
        player: nil,
        stats: nil,
        subtitles: nil,
        streams: nil,
        tags: nil,
        commentCount: nil
    )
}
#endif
