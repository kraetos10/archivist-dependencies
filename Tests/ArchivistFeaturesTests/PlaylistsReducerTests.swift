import ArchivistNetworking
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized)
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

    @Test func pullToRefreshReloads() async {
        var initialState = PlaylistsReducer.State(serverConfig: config)
        initialState.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist1])
        initialState.hasLoaded = true
        initialState.currentPage = 2

        let store = TestStore(initialState: initialState) {
            PlaylistsReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, _, _, _, _ in TestFixtures.paginatedPlaylists }
        }

        await store.send(.view(.pullToRefreshTriggered)) {
            $0.isLoading = true
            $0.currentPage = 1
        }
        await store.receive(\.playlistsResult.success) {
            $0.playlists = IdentifiedArrayOf(uniqueElements: [TestFixtures.playlist1, TestFixtures.playlist2])
            $0.isLoading = false
            $0.hasLoaded = true
        }
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

    @Test func playlistCardTappedSelectsAndPushesPlaylist() async {
        let store = TestStore(
            initialState: PlaylistsReducer.State(serverConfig: config)
        ) {
            PlaylistsReducer()
        }

        await store.send(.view(.playlistCardTapped(TestFixtures.playlist1))) {
            let detail = PlaylistDetailReducer.State(
                serverConfig: self.config,
                playlist: TestFixtures.playlist1
            )
            $0.selectedPlaylist = detail
            $0.path.append(.playlistDetail(detail))
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
}
