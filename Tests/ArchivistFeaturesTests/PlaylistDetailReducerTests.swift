import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct PlaylistDetailReducerTests {
    let config = TestFixtures.serverConfig

    private func makeState(
        _ playlist: PlaylistResponse = TestFixtures.playlistWithEntries
    ) -> PlaylistDetailReducer.State {
        PlaylistDetailReducer.State(serverConfig: config, playlist: playlist)
    }

    // MARK: - Loading

    @Test func viewDidAppearLoadsPlaylist() async {
        var initialState = makeState(TestFixtures.playlist1)
        // Pre-seed thumbnails so the post-load entry lookup is skipped,
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
        var initialState = makeState(TestFixtures.playlist1)
        initialState.hasLoadedEntries = true

        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        }

        await store.send(.view(.viewDidAppear))
    }

    @Test func playlistResultFailureClearsLoading() async {
        var initialState = makeState(TestFixtures.playlist1)
        initialState.isLoadingEntries = true

        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        }

        await store.send(.playlistResult(.failure(NSError(domain: "test", code: 0)))) {
            $0.isLoadingEntries = false
            $0.hasLoadedEntries = true
        }
    }

    /// A long playlist mustn't open a request per entry all at once.
    @Test func entryLookupsRunWithBoundedConcurrency() async {
        let entries = (0..<20).map { index in
            PlaylistEntry(
                youtubeId: "v\(index)",
                title: "Entry \(index)",
                idx: index,
                uploader: nil,
                vidThumbUrl: nil
            )
        }
        let longPlaylist = TestFixtures.playlist1.withEntries(entries)
        let inFlight = LockIsolated(0)
        let peak = LockIsolated(0)
        let lookups = LockIsolated(0)

        let store = TestStore(initialState: makeState(TestFixtures.playlist1)) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.playlistService.getPlaylist = { _, _ in longPlaylist }
            $0.videoService.getVideo = { _, _ in
                inFlight.withValue { $0 += 1 }
                peak.withValue { $0 = max($0, inFlight.value) }
                lookups.withValue { $0 += 1 }
                for _ in 0..<5 { await Task.yield() }
                inFlight.withValue { $0 -= 1 }
                throw NSError(domain: "missing", code: 404)
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingEntries = true
        }
        await store.receive(\.playlistResult.success) {
            $0.playlist = longPlaylist
            $0.isLoadingEntries = false
            $0.hasLoadedEntries = true
        }
        await store.receive(\.thumbnailsLoaded)
        #expect(lookups.value == 20)
        #expect(peak.value <= PlaylistDetailReducer.thumbnailFetchConcurrency)
    }

    // MARK: - Entries

    @Test func availableEntryLoadsVideoAndEmitsDelegate() async {
        var initialState = makeState()
        initialState.availableVideoIDs = ["video_1", "video_2"]
        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.videoService.getVideo = { _, id in
                id == "video_1" ? TestFixtures.video1 : TestFixtures.video2
            }
        }

        await store.send(.view(.entryTapped(TestFixtures.playlistEntry1)))
        await store.receive(\.videoResult)
        await store.receive(
            \.delegate,
            .showVideo(TestFixtures.video1, nextVideos: [TestFixtures.video2], loopVideoIds: [])
        )
    }

    @Test func unavailableEntryOffersToQueueIt() async {
        let store = TestStore(initialState: makeState()) {
            PlaylistDetailReducer()
        }

        await store.send(.view(.entryTapped(TestFixtures.playlistEntry1))) {
            $0.alert = AlertState {
                TextState(TestFixtures.playlistEntry1.title ?? "")
            } actions: {
                ButtonState(action: .confirmServerDownload("video_1")) {
                    TextState(String.localised("video.downloadNow", table: .videos))
                }
                ButtonState(role: .cancel) {
                    TextState(String.localised("generic.cancel", table: .generic))
                }
            } message: {
                TextState(String.localised("playlist.serverDownloadPrompt", table: .videos))
            }
        }
    }

    @Test func entryTappedWithoutIdNoOps() async {
        let entryWithoutId = PlaylistEntry(
            youtubeId: nil,
            title: "No ID Entry",
            idx: 0,
            uploader: "Test Channel 1",
            vidThumbUrl: nil
        )

        let store = TestStore(initialState: makeState()) {
            PlaylistDetailReducer()
        }

        await store.send(.view(.entryTapped(entryWithoutId)))
    }

    @Test func videoLoadFailureShowsAnAlert() async {
        var initialState = makeState()
        initialState.availableVideoIDs = ["video_1"]
        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.videoService.getVideo = { _, _ in throw NSError(domain: "test", code: 0) }
        }

        await store.send(.view(.entryTapped(TestFixtures.playlistEntry1)))
        await store.receive(\.videoResult) {
            $0.alert = .failure(String.localised("playlist.playFailed", table: .videos))
        }
    }

    // MARK: - Mark as watched

    /// "Mark as watched" used to post a progress of 0, resetting the resume
    /// position and leaving the video unwatched. It must set the flag.
    @Test func markAsWatchedSetsTheWatchedFlag() async {
        let calls = LockIsolated<[(String, Bool)]>([])
        let store = TestStore(initialState: makeState()) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, videoId, isWatched in
                calls.withValue { $0.append((videoId, isWatched)) }
            }
            // `setProgress` is left unimplemented: calling it fails the test.
        }

        await store.send(.view(.markAsWatchedTapped(TestFixtures.playlistEntry1)))
        await store.receive(\.setWatchedResult.success)
        #expect(calls.value.map(\.0) == ["video_1"])
        #expect(calls.value.map(\.1) == [true])
    }

    @Test func markAsWatchedFailureShowsAnAlert() async {
        let store = TestStore(initialState: makeState()) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.videoService.setWatched = { _, _, _ in throw NSError(domain: "test", code: 0) }
        }

        await store.send(.view(.markAsWatchedTapped(TestFixtures.playlistEntry1)))
        await store.receive(\.setWatchedResult.failure) {
            $0.alert = .failure(String.localised("video.setWatchedFailed", table: .videos))
        }
    }

    // MARK: - Editing

    @Test func removeEntryFailureShowsAnAlert() async {
        let custom = PlaylistResponse(
            playlistId: "PL_custom",
            playlistName: "Mine",
            playlistType: .custom,
            playlistChannelId: nil,
            playlistChannel: nil,
            playlistDescription: nil,
            playlistThumbnail: nil,
            playlistSubscribed: false,
            playlistActive: true,
            playlistSortOrder: nil,
            playlistLastRefresh: nil,
            playlistEntries: [TestFixtures.playlistEntry1]
        )
        let store = TestStore(initialState: makeState(custom)) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.playlistService.modifyCustomPlaylist = { _, _, _, _, _ in
                throw NSError(domain: "test", code: 0)
            }
        }

        await store.send(.view(.removeEntryTapped(TestFixtures.playlistEntry1)))
        await store.receive(\.removeEntryResult.failure) {
            $0.alert = .failure(String.localised("playlist.removeEntryFailed", table: .videos))
        }
    }

    @Test func videosAddedByThePickerReloadThePlaylist() async {
        var initialState = makeState(TestFixtures.playlist1)
        initialState.hasLoadedEntries = true
        initialState.entryThumbnails = ["video_1": "t1", "video_2": "t2"]
        initialState.videoPicker = VideoPickerReducer.State(
            serverConfig: config,
            playlistId: TestFixtures.playlist1.playlistId
        )
        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.playlistService.getPlaylist = { _, _ in TestFixtures.playlistWithEntries }
        }

        await store.send(.videoPicker(.presented(.delegate(.didAddVideos)))) {
            $0.hasLoadedEntries = false
            $0.isLoadingEntries = true
        }
        await store.receive(\.playlistResult.success) {
            $0.playlist = TestFixtures.playlistWithEntries
            $0.isLoadingEntries = false
            $0.hasLoadedEntries = true
        }
    }

    // MARK: - Unsubscribe

    @Test func unsubscribeTellsTheParent() async {
        var initialState = makeState()
        initialState.alert = AlertState { TextState("Remove") }
        let store = TestStore(initialState: initialState) {
            PlaylistDetailReducer()
        } withDependencies: {
            $0.playlistService.deletePlaylist = { _, _, _ in }
        }

        await store.send(.alert(.presented(.confirmUnsubscribe))) {
            $0.alert = nil
        }
        await store.receive(\.unsubscribeResult)
        await store.receive(\.delegate, .didUnsubscribe(TestFixtures.playlistWithEntries.playlistId))
    }

    @Test func descriptionFiltersTheServersFalsePlaceholder() {
        let placeholder = PlaylistResponse(
            playlistId: "PL",
            playlistName: "P",
            playlistType: .regular,
            playlistChannelId: nil,
            playlistChannel: nil,
            playlistDescription: "False",
            playlistThumbnail: nil,
            playlistSubscribed: false,
            playlistActive: true,
            playlistSortOrder: nil,
            playlistLastRefresh: nil,
            playlistEntries: nil
        )
        #expect(makeState(placeholder).displayDescription == nil)
        #expect(makeState(TestFixtures.playlist1).displayDescription == "A test playlist")
    }
}
