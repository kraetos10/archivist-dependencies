import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct PlaylistsReducerTests {
    let config = TestFixtures.serverConfig

    @Test func viewDidAppearLoadsPlaylists() async {
        let store = TestStore(
            initialState: PlaylistsReducer.State(serverConfig: config)
        ) {
            PlaylistsReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, _, _, _, _ in TestFixtures.paginatedPlaylists }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.playlistsResult.success) {
            $0.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist1, TestFixtures.playlist2])
            $0.currentPage = 1
            $0.lastPage = 1
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test func viewDidAppearSkipsWhenAlreadyLoaded() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist1])
        initialState.hasLoaded = true

        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        }

        await store.send(.view(.viewDidAppear))
    }

    @Test func pullToRefreshReplacesTheList() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist2])
        initialState.hasLoaded = true
        initialState.currentPage = 2

        let page1 = PaginatedResponse<PlaylistResponse>(
            data: [TestFixtures.playlist1],
            paginate: TestFixtures.paginatedPlaylists.paginate
        )
        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, _, _, _, _ in page1 }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
            $0.currentPage = 1
        }
        await store.receive(\.playlistsResult.success) {
            $0.playlists = [TestFixtures.playlist1]
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    /// A refresh started while a later page is loading cancels that page,
    /// so it can't be mistaken for the fresh first page.
    @Test func refreshCancelsAPageInFlight() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.playlists = [TestFixtures.playlist1]
        initialState.hasLoaded = true
        initialState.currentPage = 1
        initialState.lastPage = 2

        let pageGate = TestGate()
        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, page, _, _, _ in
                if page == 2 {
                    await pageGate.wait()
                    return TestFixtures.paginatedPlaylistsMultiPage(page: 2, lastPage: 2)
                }
                return TestFixtures.paginatedPlaylists
            }
        }

        await store.send(.view(.lastItemAppeared)) {
            $0.isLoadingMore = true
        }
        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
        }
        await store.receive(\.playlistsResult.success) {
            $0.playlists = [TestFixtures.playlist1, TestFixtures.playlist2]
            $0.lastPage = 1
            $0.isLoading = false
            $0.isLoadingMore = false
        }
        pageGate.open()
    }

    @Test func lastItemAppearedLoadsNextPage() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist1])
        initialState.currentPage = 1
        initialState.lastPage = 2
        initialState.hasLoaded = true

        let page2 = TestFixtures.paginatedPlaylistsMultiPage(page: 2, lastPage: 2)

        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, _, _, _, _ in page2 }
        }

        await store.send(.view(.lastItemAppeared)) {
            $0.isLoadingMore = true
        }
        await store.receive(\.playlistsResult.success) {
            $0.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist1, TestFixtures.playlist2])
            $0.currentPage = 2
            $0.lastPage = 2
            $0.isLoadingMore = false
            $0.hasLoaded = true
        }
    }

    @Test func lastItemAppearedNoOpsAtLastPage() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist1])
        initialState.currentPage = 2
        initialState.lastPage = 2
        initialState.hasLoaded = true

        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        }

        await store.send(.view(.lastItemAppeared))
    }

    @Test func playlistCardTappedPushesWithoutAlsoSelecting() async {
        let store = TestStore(
            initialState: PlaylistsReducer.State(serverConfig: config)
        ) {
            PlaylistsReducer()
        }

        await store.send(.view(.playlistCardTapped(TestFixtures.playlist1))) {
            $0.path.append(.playlistDetail(PlaylistDetailReducer.State(
                serverConfig: self.config,
                playlist: TestFixtures.playlist1
            )))
        }
    }

    @Test func playlistCardTappedInSplitViewSelectsWithoutPushing() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.useSplitView = true
        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        }

        await store.send(.view(.playlistCardTapped(TestFixtures.playlist1))) {
            $0.selectedPlaylist = PlaylistDetailReducer.State(
                serverConfig: self.config,
                playlist: TestFixtures.playlist1
            )
        }
    }

    @Test func playlistsResultFailureClearsLoading() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.isLoading = true

        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        }

        await store.send(.playlistsResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test func pushedDetailUnsubscribingPopsItsOwnElement() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.playlists = [TestFixtures.playlist1, TestFixtures.playlist2]
        initialState.path.append(.playlistDetail(PlaylistDetailReducer.State(
            serverConfig: config,
            playlist: TestFixtures.playlist1
        )))
        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        }

        await store.send(.path(.element(
            id: 0,
            action: .playlistDetail(.delegate(.didUnsubscribe(TestFixtures.playlist1.playlistId)))
        ))) {
            $0.playlists = [TestFixtures.playlist2]
            $0.path = StackState()
        }
    }

    @Test func addingAPlaylistRefreshesTheList() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.addPlaylist = AddPlaylistReducer.State(serverConfig: config)
        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, _, _, _, _ in TestFixtures.paginatedPlaylists }
        }

        await store.send(.addPlaylist(.presented(.delegate(.didAdd)))) {
            $0.isLoading = true
        }
        await store.receive(\.playlistsResult.success) {
            $0.playlists = [TestFixtures.playlist1, TestFixtures.playlist2]
            $0.isLoading = false
            $0.hasLoaded = true
        }
    }

    @Test func searchIsDebounced() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: PlaylistsReducer.State(serverConfig: config)
        ) {
            PlaylistsReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchService.search = { _, _ in
                SearchResponse(
                    videoResults: nil,
                    channelResults: nil,
                    playlistResults: [TestFixtures.playlist2]
                )
            }
        }

        await store.send(.binding(.set(\.searchQuery, "Test"))) {
            $0.searchQuery = "Test"
            $0.isSearching = true
        }
        await clock.advance(by: .milliseconds(399))
        await clock.advance(by: .milliseconds(1))
        await store.receive(\.searchResult.success) {
            $0.searchResults = [TestFixtures.playlist2]
            $0.isSearching = false
        }
    }
}
