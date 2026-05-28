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
struct ChannelsReducerTests {
    let config = TestFixtures.serverConfig

    @Test func viewDidAppearLoadsChannels() async {
        let store = TestStore(
            initialState: ChannelsReducer.State(serverConfig: config)
        ) {
            ChannelsReducer()
        } withDependencies: {
            $0.channelService.getChannels = { _, _, _, _ in TestFixtures.paginatedChannels }
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.emptyVideos }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingUnwatchedIds = true
            $0.isLoading = true
        }
        await store.receive(\.unwatchedChannelIdsLoaded) {
            $0.channelIdsWithUnwatchedVideos = []
            $0.isLoadingUnwatchedIds = false
        }
        await store.receive(\.channelsResult.success) {
            $0.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1, TestFixtures.channel2])
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test func viewDidAppearSkipsChannelLoadWhenLoaded() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1])
        initialState.hasLoaded = true

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.emptyVideos }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingUnwatchedIds = true
        }
        await store.receive(\.unwatchedChannelIdsLoaded) {
            $0.channelIdsWithUnwatchedVideos = []
            $0.isLoadingUnwatchedIds = false
        }
    }

    @Test func pullToRefreshReloads() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1])
        initialState.hasLoaded = true
        initialState.currentPage = 2

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        } withDependencies: {
            $0.channelService.getChannels = { _, _, _, _ in TestFixtures.paginatedChannels }
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.emptyVideos }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
            $0.currentPage = 1
            $0.isLoadingUnwatchedIds = true
        }
        await store.receive(\.unwatchedChannelIdsLoaded) {
            $0.channelIdsWithUnwatchedVideos = []
            $0.isLoadingUnwatchedIds = false
        }
        await store.receive(\.channelsResult.success) {
            $0.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1, TestFixtures.channel2])
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test func lastItemAppearedLoadsNextPage() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1])
        initialState.currentPage = 1
        initialState.lastPage = 2
        initialState.hasLoaded = true

        let page2 = TestFixtures.paginatedChannelsMultiPage(page: 2, lastPage: 2)

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        } withDependencies: {
            $0.channelService.getChannels = { _, _, _, _ in page2 }
        }

        await store.send(.view(.lastItemAppeared)) {
            $0.isLoadingMore = true
        }
        await store.receive(\.channelsResult.success) {
            $0.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1, TestFixtures.channel2])
            $0.currentPage = 2
            $0.lastPage = 2
            $0.isLoadingMore = false
            $0.hasLoaded = true
        }
    }

    @Test func lastItemAppearedNoOpsAtLastPage() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1])
        initialState.currentPage = 2
        initialState.lastPage = 2
        initialState.hasLoaded = true

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.view(.lastItemAppeared))
    }

    @Test func channelTappedSelectsAndPushesChannel() async {
        let store = TestStore(
            initialState: ChannelsReducer.State(serverConfig: config)
        ) {
            ChannelsReducer()
        }

        await store.send(.view(.channelTapped(TestFixtures.channel1))) {
            let detail = ChannelDetailReducer.State(
                serverConfig: self.config,
                channel: TestFixtures.channel1
            )
            $0.selectedChannel = detail
            $0.path.append(.channelDetail(detail))
        }
    }

    @Test func unsubscribeResultRemovesChannel() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1, TestFixtures.channel2])
        initialState.hasLoaded = true

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.unsubscribeResult(.success(TestFixtures.channel1.channelId))) {
            $0.channels.remove(id: TestFixtures.channel1.channelId)
        }
    }

    @Test func channelsResultFailureClearsLoading() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.isLoading = true

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.channelsResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test func channelsResultAppendsOnNextPage() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1])
        initialState.isLoadingMore = true
        initialState.hasLoaded = true

        let page2 = TestFixtures.paginatedChannelsMultiPage(page: 2, lastPage: 2)

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.channelsResult(.success(page2))) {
            $0.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1, TestFixtures.channel2])
            $0.currentPage = 2
            $0.lastPage = 2
            $0.isLoadingMore = false
            $0.hasLoaded = true
        }
    }
}
