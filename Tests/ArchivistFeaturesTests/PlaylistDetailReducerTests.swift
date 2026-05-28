import ArchivistNetworking
import ComposableArchitecture
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized)
struct PlaylistDetailReducerTests {
    let config = TestFixtures.serverConfig

    @Test func viewDidAppearLoadsPlaylist() async {
        var initialState = PlaylistDetailReducer.State(
            serverConfig: config,
            playlist: TestFixtures.playlist1
        )
        // Pre-seed thumbnails so the post-load thumbnail fetch is skipped,
        // keeping this focused on the load itself.
        initialState.entryThumbnails = ["video_1": "t1", "video_2": "t2"]

        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.playlistService.getPlaylist = { _, _ in TestFixtures.playlistWithEntries }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingEntries = true
        }
        await store.receive(\.playlistResult.success) {
            $0.playlist = TestFixtures.playlistWithEntries
            $0.isLoadingEntries = false
            $0.hasLoadedEntries = true
        }
    }

    @Test func viewDidAppearSkipsWhenLoaded() async {
        var initialState = PlaylistDetailReducer.State(
            serverConfig: config,
            playlist: TestFixtures.playlist1
        )
        initialState.hasLoadedEntries = true

        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        }

        await store.send(.view(.viewDidAppear))
    }

    @Test func playlistResultFailureClearsLoading() async {
        var initialState = PlaylistDetailReducer.State(
            serverConfig: config,
            playlist: TestFixtures.playlist1
        )
        initialState.isLoadingEntries = true

        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        }

        await store.send(.playlistResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoadingEntries = false
            $0.hasLoadedEntries = true
        }
    }

    @Test func entryTappedLoadsVideoAndEmitsDelegate() async {
        let store = TestStore(
            initialState: PlaylistDetailReducer.State(
                serverConfig: config,
                playlist: TestFixtures.playlistWithEntries
            )
        ) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.videoService.getVideo = { _, id in
                id == "video_1" ? TestFixtures.video1 : TestFixtures.video2
            }
        }

        await store.send(.view(.entryTapped(TestFixtures.playlistEntry1)))
        await store.receive(\.videoResult)
        await store.receive(\.delegate)
    }

    @Test func entryTappedWithoutIdNoOps() async {
        let entryWithoutId = PlaylistEntry(
            youtubeId: nil,
            title: "No ID Entry",
            idx: 0,
            uploader: "Test Channel 1",
            vidThumbUrl: nil
        )

        let store = TestStore(
            initialState: PlaylistDetailReducer.State(
                serverConfig: config,
                playlist: TestFixtures.playlistWithEntries
            )
        ) {
            PlaylistDetailReducer()
        }

        await store.send(.view(.entryTapped(entryWithoutId)))
    }
}
