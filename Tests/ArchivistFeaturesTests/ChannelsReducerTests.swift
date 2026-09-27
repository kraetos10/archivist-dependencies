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
    .timeLimit(.minutes(1)),
    .dependencies { $0.defaultDatabase = try TubeData.shared.inMemoryDatabase() }
)
struct ChannelsReducerTests {
    let config = TestFixtures.serverConfig

    // MARK: - Loading

    @Test func viewDidAppearLoadsChannels() async {
        let unwatchedGate = TestGate()
        let store = TestStore(
            initialState: ChannelsReducer.State(serverConfig: config)
        ) {
            ChannelsReducer()
        } withDependencies: {
            $0.channelService.getChannels = { _, _, _, _ in TestFixtures.paginatedChannels }
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in
                await unwatchedGate.wait()
                return TestFixtures.emptyVideos
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingUnwatchedIds = true
            $0.isLoading = true
        }
        await store.receive(\.channelsResult.success) {
            $0.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1, TestFixtures.channel2])
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoading = false
            $0.hasLoaded = true
        }
        unwatchedGate.open()
        await store.receive(\.unwatchedChannelIdsLoaded) {
            $0.channelIdsWithUnwatchedVideos = []
            $0.isLoadingUnwatchedIds = false
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

    @Test func pullToRefreshReplacesTheList() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        // A channel the server no longer has: a refresh must drop it.
        initialState.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel2])
        initialState.hasLoaded = true
        initialState.currentPage = 2

        let unwatchedGate = TestGate()
        let page1 = PaginatedResponse<ChannelResponse>(
            data: [TestFixtures.channel1],
            paginate: TestFixtures.paginateInfoPage1
        )
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        } withDependencies: {
            $0.channelService.getChannels = { _, _, _, _ in page1 }
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in
                await unwatchedGate.wait()
                return TestFixtures.emptyVideos
            }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
            $0.currentPage = 1
            $0.isLoadingUnwatchedIds = true
        }
        await store.receive(\.channelsResult.success) {
            $0.channels = IdentifiedArrayOf(uniqueElements: [TestFixtures.channel1])
            $0.isLoading = false
            $0.hasLoaded = true
        }
        unwatchedGate.open()
        await store.receive(\.unwatchedChannelIdsLoaded) {
            $0.isLoadingUnwatchedIds = false
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

    @Test func lastItemAppearedWaitsForARefresh() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.currentPage = 1
        initialState.lastPage = 3
        initialState.isLoading = true

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.view(.lastItemAppeared))
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

    // MARK: - Search

    @Test func searchIsDebouncedAndOnlyTheLastQueryRuns() async {
        let clock = TestClock()
        let queries = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: ChannelsReducer.State(serverConfig: config)
        ) {
            ChannelsReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchService.search = { _, query in
                queries.withValue { $0.append(query) }
                return SearchResponse(
                    videoResults: nil,
                    channelResults: [TestFixtures.channel2],
                    playlistResults: nil
                )
            }
        }

        await store.send(.binding(.set(\.searchQuery, "Te"))) {
            $0.searchQuery = "Te"
            $0.isSearching = true
        }
        await clock.advance(by: .milliseconds(200))
        await store.send(.binding(.set(\.searchQuery, "Test"))) {
            $0.searchQuery = "Test"
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchResult.success) {
            $0.searchResults = [TestFixtures.channel2]
            $0.isSearching = false
        }
        #expect(queries.value == ["Test"])
    }

    @Test func clearingTheSearchCancelsIt() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: ChannelsReducer.State(serverConfig: config)
        ) {
            ChannelsReducer()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.searchQuery, "Te"))) {
            $0.searchQuery = "Te"
            $0.isSearching = true
        }
        await store.send(.binding(.set(\.searchQuery, ""))) {
            $0.searchQuery = ""
            $0.isSearching = false
        }
        await clock.run()
    }

    // MARK: - Navigation

    @Test func channelTappedPushesWithoutAlsoSelecting() async {
        let store = TestStore(
            initialState: ChannelsReducer.State(serverConfig: config)
        ) {
            ChannelsReducer()
        }

        await store.send(.view(.channelTapped(TestFixtures.channel1))) {
            $0.path.append(.channelDetail(ChannelDetailReducer.State(
                serverConfig: self.config,
                channel: TestFixtures.channel1
            )))
        }
    }

    @Test func channelTappedInSplitViewSelectsWithoutPushing() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.useSplitView = true
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.view(.channelTapped(TestFixtures.channel1))) {
            $0.selectedChannel = ChannelDetailReducer.State(
                serverConfig: self.config,
                channel: TestFixtures.channel1
            )
        }
        // Tapping the channel already shown does nothing.
        await store.send(.view(.channelTapped(TestFixtures.channel1)))
    }

    @Test func splitViewAppearingAdoptsAPushedDetail() async {
        let detail = ChannelDetailReducer.State(serverConfig: config, channel: TestFixtures.channel1)
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = [TestFixtures.channel1]
        initialState.path.append(.channelDetail(detail))

        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.emptyVideos }
        }

        await store.send(.view(.splitViewDidAppear)) {
            $0.useSplitView = true
            $0.selectedChannel = detail
            $0.path = StackState()
            $0.isLoadingUnwatchedIds = true
        }
        await store.receive(\.unwatchedChannelIdsLoaded) {
            $0.isLoadingUnwatchedIds = false
        }
    }

    @Test func openChannelReplacesThePushedStack() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.path.append(
            .channelDetail(ChannelDetailReducer.State(serverConfig: config, channel: TestFixtures.channel2))
        )
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }
        let channel = ChannelResponse(videoChannel: TestFixtures.video1.channel)
        let detail = ChannelDetailReducer.State(serverConfig: config, channel: channel)

        await store.send(.openChannel(channel)) {
            $0.path = StackState([.channelDetail(detail)])
        }
    }

    @Test func openChannelInSplitViewSelectsWithoutPushing() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.useSplitView = true
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }
        let channel = ChannelResponse(videoChannel: TestFixtures.video1.channel)

        await store.send(.openChannel(channel)) {
            $0.selectedChannel = ChannelDetailReducer.State(serverConfig: config, channel: channel)
        }
    }

    @Test func channelFromAVideoKeepsItsIdentityAndDefaultsTheRest() {
        let channel = ChannelResponse(videoChannel: TestFixtures.video1.channel)

        #expect(channel.channelId == "UC_channel1")
        #expect(channel.channelName == "Test Channel 1")
        #expect(channel.channelActive)
        #expect(!channel.channelSubscribed)
        #expect(channel.channelOverwrites == nil)
    }

    // MARK: - Unsubscribe

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

    @Test func unsubscribeFailureShowsAnAlert() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = [TestFixtures.channel1]
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.unsubscribeResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.alert = .unsubscribeFailed
        }
    }

    @Test func pushedDetailUnsubscribingPopsItsOwnElement() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.channels = [TestFixtures.channel1, TestFixtures.channel2]
        initialState.path.append(
            .channelDetail(ChannelDetailReducer.State(serverConfig: config, channel: TestFixtures.channel1))
        )
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.path(.element(
            id: 0,
            action: .channelDetail(.delegate(.didUnsubscribe(TestFixtures.channel1.channelId)))
        ))) {
            $0.channels = [TestFixtures.channel2]
            $0.path = StackState()
        }
    }

    @Test func selectedDetailUnsubscribingClearsTheSelection() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.useSplitView = true
        initialState.channels = [TestFixtures.channel1, TestFixtures.channel2]
        initialState.selectedChannel = ChannelDetailReducer.State(
            serverConfig: config,
            channel: TestFixtures.channel1
        )
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        }

        await store.send(.channelDetail(.presented(.delegate(.didUnsubscribe(TestFixtures.channel1.channelId))))) {
            $0.channels = [TestFixtures.channel2]
            $0.selectedChannel = nil
        }
    }

    // MARK: - Pending downloads

    @Test func refreshPendingDownloadsReachesPushedDetails() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.path.append(
            .channelDetail(ChannelDetailReducer.State(serverConfig: config, channel: TestFixtures.channel1))
        )
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        } withDependencies: {
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in TestFixtures.paginatedDownloads }
        }

        await store.send(.refreshPendingDownloads)
        await store.receive(\.path[id: 0].channelDetail.refreshPendingDownloads)
        await store.receive(\.path[id: 0].channelDetail.downloadsResult.success) {
            $0.path[id: 0, case: \.channelDetail]?.pendingDownloads = [
                TestFixtures.download2,
                TestFixtures.download1,
            ]
            $0.path[id: 0, case: \.channelDetail]?.hasLoadedDownloads = true
        }
    }

    // MARK: - Add channel

    @Test func subscribingRefreshesTheList() async {
        var initialState = ChannelsReducer.State(serverConfig: config)
        initialState.addChannel = AddChannelReducer.State(serverConfig: config)
        let unwatchedGate = TestGate()
        let store = TestStore(initialState: initialState) {
            ChannelsReducer()
        } withDependencies: {
            $0.channelService.getChannels = { _, _, _, _ in TestFixtures.paginatedChannels }
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in
                await unwatchedGate.wait()
                return TestFixtures.emptyVideos
            }
        }

        await store.send(.addChannel(.presented(.delegate(.didSubscribe)))) {
            $0.isLoading = true
            $0.isLoadingUnwatchedIds = true
        }
        await store.receive(\.channelsResult.success) {
            $0.channels = [TestFixtures.channel1, TestFixtures.channel2]
            $0.isLoading = false
            $0.hasLoaded = true
        }
        unwatchedGate.open()
        await store.receive(\.unwatchedChannelIdsLoaded) {
            $0.isLoadingUnwatchedIds = false
        }
    }

    // MARK: - Content

    @Test func contentFollowsTheFilterAndSearch() {
        var state = ChannelsReducer.State(serverConfig: config)
        state.isLoading = true
        #expect(state.content == .placeholders)

        state.isLoading = false
        state.hasLoaded = true
        #expect(state.content == .noChannels)

        state.searchQuery = "nothing"
        #expect(state.content == .noSearchResults)

        state.searchQuery = ""
        state.channels = [TestFixtures.channel1, TestFixtures.channel2]
        state.channelIdsWithUnwatchedVideos = [TestFixtures.channel2.channelId]
        state.$filter.withLock { $0 = .withUnwatched }
        #expect(state.content == .channels([TestFixtures.channel2]))

        state.channelIdsWithUnwatchedVideos = []
        #expect(state.content == .emptyUnwatched)

        // The filter is persisted; don't leave it set for other tests.
        state.$filter.withLock { $0 = .all }
    }
}
