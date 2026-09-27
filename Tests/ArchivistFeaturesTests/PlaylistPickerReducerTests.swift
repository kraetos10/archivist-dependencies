import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct PlaylistPickerReducerTests {
    let config = TestFixtures.serverConfig

    private func makeState() -> PlaylistPickerReducer.State {
        PlaylistPickerReducer.State(serverConfig: config, videoId: "video_1")
    }

    @Test func loadingMarksPlaylistsThatAlreadyHoldTheVideo() async {
        let store = TestStore(initialState: makeState()) {
            PlaylistPickerReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, page, type, _, _ in
                #expect(type == "custom")
                return TestFixtures.paginatedPlaylistsMultiPage(page: page, lastPage: 2)
            }
            $0.playlistService.getPlaylist = { _, id in
                id == TestFixtures.playlist1.playlistId
                    ? TestFixtures.playlistWithEntries
                    : TestFixtures.playlist2
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.loadResult.success) {
            $0.playlists = [TestFixtures.playlist1, TestFixtures.playlist2]
            $0.alreadyInPlaylistIds = [TestFixtures.playlist1.playlistId]
            $0.lastPage = 2
            $0.isLoading = false
        }
    }

    @Test func lastItemAppearedLoadsTheNextPage() async {
        var initialState = makeState()
        initialState.playlists = [TestFixtures.playlist1]
        initialState.currentPage = 1
        initialState.lastPage = 2
        let store = TestStore(initialState: initialState) {
            PlaylistPickerReducer()
        } withDependencies: {
            $0.playlistService.getPlaylists = { _, page, _, _, _ in
                PaginatedResponse(
                    data: [TestFixtures.playlist2],
                    paginate: TestFixtures.paginatedPlaylistsMultiPage(page: page, lastPage: 2).paginate
                )
            }
            $0.playlistService.getPlaylist = { _, _ in TestFixtures.playlist2 }
        }

        await store.send(.view(.lastItemAppeared)) {
            $0.isLoadingMore = true
        }
        await store.receive(\.loadResult.success) {
            $0.playlists = [TestFixtures.playlist1, TestFixtures.playlist2]
            $0.currentPage = 2
            $0.isLoadingMore = false
        }
        // Last page: nothing more to fetch.
        await store.send(.view(.lastItemAppeared))
    }

    @Test func tappingAPlaylistAddsTheVideoAndDismisses() async {
        let dismissed = LockIsolated(false)
        var initialState = makeState()
        initialState.playlists = [TestFixtures.playlist2]
        let store = TestStore(initialState: initialState) {
            PlaylistPickerReducer()
        } withDependencies: {
            $0.playlistService.modifyCustomPlaylist = { _, id, action, videoId, _ in
                #expect(id == TestFixtures.playlist2.playlistId)
                #expect(action == "create")
                #expect(videoId == "video_1")
            }
        }
        store.dependencies.dismiss = DismissEffect { dismissed.setValue(true) }

        await store.send(.view(.playlistTapped(TestFixtures.playlist2))) {
            $0.isAdding = true
        }
        await store.receive(\.addResult) {
            $0.isAdding = false
        }
        #expect(dismissed.value)
    }

    @Test func aPlaylistThatHasTheVideoCannotBeTapped() async {
        var initialState = makeState()
        initialState.playlists = [TestFixtures.playlist1]
        initialState.alreadyInPlaylistIds = [TestFixtures.playlist1.playlistId]
        let store = TestStore(initialState: initialState) {
            PlaylistPickerReducer()
        }

        await store.send(.view(.playlistTapped(TestFixtures.playlist1)))
    }

    @Test func addFailureShowsAnAlert() async {
        let store = TestStore(initialState: makeState()) {
            PlaylistPickerReducer()
        } withDependencies: {
            $0.playlistService.modifyCustomPlaylist = { _, _, _, _, _ in
                throw NSError(domain: "test", code: 0)
            }
        }

        await store.send(.view(.playlistTapped(TestFixtures.playlist2))) {
            $0.isAdding = true
        }
        await store.receive(\.addResult) {
            $0.isAdding = false
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(String.localised("playlist.addVideoFailed", table: .videos))
            }
        }
    }
}
