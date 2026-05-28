import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import SQLiteData
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(
    .serialized,
    .dependencies { $0.defaultDatabase = try TubeData.shared.inMemoryDatabase() }
)
struct ChannelDetailReducerTests {
    let config = TestFixtures.serverConfig

    @Test func viewDidAppearLoadsVideosAndDownloads() async {
        let store = TestStore(
            initialState: ChannelDetailReducer.State(
                serverConfig: config,
                channel: TestFixtures.channel1
            )
        ) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.paginatedVideos }
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in TestFixtures.paginatedDownloads }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingVideos = true
            $0.isLoadingDownloads = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1, TestFixtures.video2])
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
        await store.receive(\.downloadsResult.success) {
            $0.pendingDownloads = IdentifiedArrayOf(uniqueElements: [TestFixtures.download2, TestFixtures.download1])
            $0.isLoadingDownloads = false
            $0.hasLoadedDownloads = true
        }
    }

    @Test func viewDidAppearSkipsWhenAlreadyLoaded() async {
        var initialState = ChannelDetailReducer.State(
            serverConfig: config,
            channel: TestFixtures.channel1
        )
        initialState.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1])
        initialState.hasLoadedVideos = true
        initialState.pendingDownloads = IdentifiedArrayOf(uniqueElements: [TestFixtures.download1])
        initialState.hasLoadedDownloads = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.view(.viewDidAppear))
    }

    @Test func videosResultPopulatesVideos() async {
        var initialState = ChannelDetailReducer.State(
            serverConfig: config,
            channel: TestFixtures.channel1
        )
        initialState.isLoadingVideos = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.videosResult(.success(TestFixtures.paginatedVideos))) {
            $0.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1, TestFixtures.video2])
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
    }

    @Test func videosResultFailureClearsLoading() async {
        var initialState = ChannelDetailReducer.State(
            serverConfig: config,
            channel: TestFixtures.channel1
        )
        initialState.isLoadingVideos = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.videosResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoadingVideos = false
            $0.hasLoadedVideos = true
        }
    }

    @Test func lastVideoAppearedLoadsNextPage() async {
        var initialState = ChannelDetailReducer.State(
            serverConfig: config,
            channel: TestFixtures.channel1
        )
        initialState.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1])
        initialState.hasLoadedVideos = true
        initialState.currentPage = 1
        initialState.lastPage = 2

        let page2 = TestFixtures.paginatedVideosMultiPage(page: 2, lastPage: 2)

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in page2 }
        }

        await store.send(.view(.lastVideoAppeared)) {
            $0.isLoadingMoreVideos = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = IdentifiedArrayOf(uniqueElements: [TestFixtures.video1, TestFixtures.video2])
            $0.currentPage = 2
            $0.lastPage = 2
            $0.isLoadingMoreVideos = false
            $0.hasLoadedVideos = true
        }
    }

    @Test func videoCardTappedEmitsDelegate() async {
        let store = TestStore(
            initialState: ChannelDetailReducer.State(
                serverConfig: config,
                channel: TestFixtures.channel1
            )
        ) {
            ChannelDetailReducer()
        }

        await store.send(.view(.videoCardTapped(TestFixtures.video1)))
        await store.receive(\.delegate)
    }

    @Test func downloadCardTappedPresentsDownloadDetail() async {
        let store = TestStore(
            initialState: ChannelDetailReducer.State(
                serverConfig: config,
                channel: TestFixtures.channel1
            )
        ) {
            ChannelDetailReducer()
        }

        await store.send(.view(.downloadCardTapped(TestFixtures.download1))) {
            $0.downloadDetail = DownloadDetailReducer.State(
                serverConfig: self.config,
                download: TestFixtures.download1
            )
        }
    }

    @Test func downloadsResultFailureClearsLoading() async {
        var initialState = ChannelDetailReducer.State(
            serverConfig: config,
            channel: TestFixtures.channel1
        )
        initialState.isLoadingDownloads = true

        let store = TestStore(initialState: initialState) {
            ChannelDetailReducer()
        }

        await store.send(.downloadsResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoadingDownloads = false
            $0.hasLoadedDownloads = true
        }
    }
}
