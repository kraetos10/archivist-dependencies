#if os(watchOS)
@testable import ArchivistNetworking
@testable import ArchivistWatch
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WatchVideoListViewModelTests {
    @Test func loadsOnceOnAppearAndAgainOnRefresh() async {
        let calls = LockIsolated(0)
        var service = VideoService()
        service.getVideos = { _, page, _, _, _, _, _, _ in
            calls.withValue { $0 += 1 }
            return WatchFixtures.videoPage(["a", "b"], page: page)
        }
        let viewModel = WatchVideoListViewModel(
            config: WatchFixtures.config,
            service: service,
            playback: WatchFixtures.playback()
        )

        await viewModel.viewDidAppear()
        await viewModel.viewDidAppear()
        #expect(calls.value == 1)
        #expect(viewModel.videos.map(\.id) == ["a", "b"])
        #expect(!viewModel.isLoading)

        await viewModel.refresh()
        #expect(calls.value == 2)
    }

    @Test func theLastRowLoadsTheNextPage() async {
        var service = VideoService()
        service.getVideos = { _, page, _, _, _, _, _, _ in
            page == 1
                ? WatchFixtures.videoPage(["a", "b"], page: 1, lastPage: 2)
                : WatchFixtures.videoPage(["b", "c"], page: 2, lastPage: 2)
        }
        let viewModel = WatchVideoListViewModel(
            config: WatchFixtures.config,
            service: service,
            playback: WatchFixtures.playback()
        )
        await viewModel.viewDidAppear()

        await viewModel.rowAppeared(WatchFixtures.video("a"))
        #expect(viewModel.videos.map(\.id) == ["a", "b"])

        await viewModel.rowAppeared(WatchFixtures.video("b"))
        #expect(viewModel.videos.map(\.id) == ["a", "b", "c"])
        #expect(!viewModel.isLoadingMore)

        await viewModel.rowAppeared(WatchFixtures.video("c"))
        #expect(viewModel.videos.count == 3)
    }

    @Test func aFailedLoadShowsAnErrorAndRetriesOnTheNextAppearance() async {
        let shouldFail = LockIsolated(true)
        var service = VideoService()
        service.getVideos = { _, _, _, _, _, _, _, _ in
            if shouldFail.value { throw TestError() }
            return WatchFixtures.videoPage(["a"])
        }
        let viewModel = WatchVideoListViewModel(
            config: WatchFixtures.config,
            service: service,
            playback: WatchFixtures.playback()
        )

        await viewModel.viewDidAppear()
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.videos.isEmpty)

        shouldFail.setValue(false)
        await viewModel.viewDidAppear()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.videos.map(\.id) == ["a"])
    }

    @Test func aChannelListAsksForThatChannel() async {
        let channel = LockIsolated<String?>(nil)
        var service = VideoService()
        service.getVideos = { _, _, _, _, _, _, requested, _ in
            channel.setValue(requested)
            return WatchFixtures.videoPage([])
        }
        let viewModel = WatchVideoListViewModel(
            config: WatchFixtures.config,
            channelId: "UC42",
            service: service,
            playback: WatchFixtures.playback()
        )
        await viewModel.viewDidAppear()
        #expect(channel.value == "UC42")
    }

    @Test func theSameVideoGetsTheSamePlayer() {
        let viewModel = WatchVideoListViewModel(
            config: WatchFixtures.config,
            service: VideoService(),
            playback: WatchFixtures.playback()
        )
        let first = viewModel.player(for: WatchFixtures.video("a"))
        #expect(viewModel.player(for: WatchFixtures.video("a")) === first)
        #expect(viewModel.player(for: WatchFixtures.video("b")) !== first)
    }

    @Test func rowsShowDownloadsFromTheCatalog() throws {
        let catalog = WatchDownloadCatalog()
        catalog.setup(database: try WatchData.shared.inMemoryDatabase(), storage: WatchFixtures.temporaryStorage())
        catalog.add(
            WatchDownload(
                id: "a",
                title: "A",
                channelName: "C",
                duration: nil,
                durationStr: nil,
                fileSize: nil,
                downloadedAt: 0,
                lastPlayedPosition: 0,
                thumbPath: nil
            )
        )
        let viewModel = WatchVideoListViewModel(
            config: WatchFixtures.config,
            service: VideoService(),
            playback: WatchFixtures.playback(catalog: catalog)
        )
        #expect(viewModel.rowModel(for: WatchFixtures.video("a")).isDownloaded)
        #expect(!viewModel.rowModel(for: WatchFixtures.video("b")).isDownloaded)
        #expect(
            viewModel.rowModel(for: WatchFixtures.video("a")).thumbnailURL?.absoluteString
                == "https://tube.example.com/cache/a.jpg"
        )
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WatchServerQueueViewModelTests {
    @Test func recentlyAddedShowsTheLastPageNewestFirst() async {
        let pages = LockIsolated<[Int]>([])
        var service = DownloadService()
        service.getDownloads = { _, page, _, _, _, _ in
            pages.withValue { $0.append(page) }
            return page == 1
                ? WatchFixtures.downloadPage(["1", "2"], page: 1, lastPage: 3)
                : WatchFixtures.downloadPage(["7", "8"], page: page, lastPage: 3)
        }
        let viewModel = WatchServerQueueViewModel(config: WatchFixtures.config, service: service)

        await viewModel.viewDidAppear()
        #expect(pages.value == [1, 3])
        #expect(viewModel.downloads.map(\.id) == ["8", "7"])

        await viewModel.sortOrderButtonTapped()
        #expect(viewModel.sortOrder == .oldestAdded)
        #expect(viewModel.downloads.map(\.id) == ["1", "2"])
    }

    @Test func aFailedRemovalPutsTheRowBack() async {
        var service = DownloadService()
        service.getDownloads = { _, _, _, _, _, _ in WatchFixtures.downloadPage(["1", "2"]) }
        service.deleteDownload = { _, _ in throw TestError() }
        let viewModel = WatchServerQueueViewModel(config: WatchFixtures.config, service: service)
        await viewModel.viewDidAppear()

        viewModel.downloadTapped(WatchFixtures.download("1"))
        #expect(viewModel.isShowingDownloadActions)
        await viewModel.removeSelectedTapped()

        #expect(!viewModel.isShowingDownloadActions)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.downloads.map(\.id) == ["2", "1"])
    }

    @Test func removingDeletesOnTheServer() async {
        let deleted = LockIsolated<[String]>([])
        var service = DownloadService()
        service.getDownloads = { _, _, _, _, _, _ in WatchFixtures.downloadPage(["1", "2"]) }
        service.deleteDownload = { _, id in deleted.withValue { $0.append(id) } }
        let viewModel = WatchServerQueueViewModel(config: WatchFixtures.config, service: service)
        await viewModel.viewDidAppear()

        viewModel.downloadTapped(WatchFixtures.download("1"))
        await viewModel.removeSelectedTapped()
        #expect(deleted.value == ["1"])
        #expect(viewModel.downloads.map(\.id) == ["2"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func addingRefreshesTheQueueAndClosesTheSheet() async throws {
        let calls = LockIsolated(0)
        var service = DownloadService()
        service.getDownloads = { _, _, _, _, _, _ in
            calls.withValue { $0 += 1 }
            return WatchFixtures.downloadPage([])
        }
        service.addDownloads = { _, _, _, _, _ in }
        let viewModel = WatchServerQueueViewModel(config: WatchFixtures.config, service: service)

        viewModel.addButtonTapped()
        let sheet = try #require(viewModel.addDownload)
        sheet.urlText = "https://youtu.be/abc123"
        await sheet.addButtonTapped()
        #expect(sheet.didAdd)

        await viewModel.downloadAdded()
        #expect(viewModel.addDownload == nil)
        #expect(calls.value == 1)
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WatchAppStateTests {
    @Test func tabsAreRebuiltOnlyWhenTheConfigurationChanges() {
        let appState = WatchAppState(
            config: WatchAppConfig(appGroupSuite: "tests.\(UUID().uuidString)", backgroundSessionIdentifier: "tests"),
            playback: WatchFixtures.playback()
        )
        #expect(appState.tabs == nil)

        appState.apply(WatchFixtures.config)
        let first = appState.tabs
        #expect(first?.config == WatchFixtures.config)

        appState.apply(WatchFixtures.config)
        #expect(appState.tabs === first)

        let newToken = ServerConfig(baseURL: "tube.example.com", apiToken: "new")
        appState.apply(newToken)
        #expect(appState.tabs !== first)
        #expect(appState.tabs?.videos.config == newToken)

        appState.apply(nil)
        #expect(appState.tabs == nil)
    }

    @Test func loadingWithNothingStoredFinishesWithoutTabs() {
        let appState = WatchAppState(
            config: WatchAppConfig(appGroupSuite: "tests.\(UUID().uuidString)", backgroundSessionIdentifier: "tests"),
            playback: WatchFixtures.playback()
        )
        appState.loadServerConfig()
        #expect(!appState.isLoading)
        #expect(appState.tabs == nil)
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WatchDownloadsViewModelTests {
    @Test func storageAndProgressComeFromTheRecords() throws {
        let catalog = WatchDownloadCatalog()
        catalog.setup(database: try WatchData.shared.inMemoryDatabase(), storage: WatchFixtures.temporaryStorage())
        let record = WatchDownload(
            id: "a",
            title: "A",
            channelName: "C",
            duration: 100,
            durationStr: "1:40",
            fileSize: 1_000,
            downloadedAt: 0,
            lastPlayedPosition: 25,
            thumbPath: nil
        )
        catalog.add(record)
        let viewModel = WatchDownloadsViewModel(
            config: WatchFixtures.config,
            playback: WatchFixtures.playback(catalog: catalog)
        )

        #expect(viewModel.formattedStorageUsed == Int64(1_000).formatted(.byteCount(style: .file)))
        #expect(viewModel.watchProgress(for: record) == 0.25)
        #expect(viewModel.remainingSeconds(for: record) == 75)
        #expect(viewModel.rowModel(for: record).subtitle == WatchVideoRowModel.remainingText(seconds: 75))
        #expect(!viewModel.isEmpty)
    }

    @Test func deletingTheSelectedRecordRemovesIt() throws {
        let storage = WatchFixtures.temporaryStorage()
        let catalog = WatchDownloadCatalog()
        catalog.setup(database: try WatchData.shared.inMemoryDatabase(), storage: storage)
        let record = WatchDownload(
            id: "a",
            title: "A",
            channelName: "C",
            duration: nil,
            durationStr: nil,
            fileSize: nil,
            downloadedAt: 0,
            lastPlayedPosition: 0,
            thumbPath: nil
        )
        catalog.add(record)
        let viewModel = WatchDownloadsViewModel(
            config: WatchFixtures.config,
            playback: WatchFixtures.playback(catalog: catalog, storage: storage)
        )

        viewModel.recordActionsTapped(record)
        #expect(viewModel.isShowingRecordActions)
        #expect(viewModel.selectedRecordTitle == "A")
        viewModel.deleteSelectedRecordConfirmed()

        #expect(viewModel.records.isEmpty)
        #expect(!viewModel.isShowingRecordActions)
        #expect(viewModel.errorMessage == nil)
    }
}
#endif
