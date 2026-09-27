import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct PlaylistVideoPickerReducerTests {
    let config = TestFixtures.serverConfig

    private func makeState() -> VideoPickerReducer.State {
        VideoPickerReducer.State(serverConfig: config, playlistId: "PL_custom")
    }

    @Test func togglingKeepsThePickOrder() async {
        let store = TestStore(initialState: makeState()) {
            VideoPickerReducer()
        }

        await store.send(.view(.videoToggled(.video(TestFixtures.video2)))) {
            $0.selectedVideoIds = ["video_2"]
        }
        await store.send(.view(.videoToggled(.video(TestFixtures.video1)))) {
            $0.selectedVideoIds = ["video_2", "video_1"]
        }
        await store.send(.view(.videoToggled(.video(TestFixtures.video2)))) {
            $0.selectedVideoIds = ["video_1"]
        }
    }

    /// Videos are added one after another, in pick order, then the picker
    /// tells the playlist and closes.
    @Test func addingIsSequentialAndInPickOrder() async {
        let added = LockIsolated<[String]>([])
        let dismissed = LockIsolated(false)
        var initialState = makeState()
        initialState.selectedVideoIds = ["video_2", "video_1", "video_watched"]
        let store = TestStore(initialState: initialState) {
            VideoPickerReducer()
        } withDependencies: {
            $0.playlistService.modifyCustomPlaylist = { _, _, _, videoId, _ in
                if let videoId {
                    added.withValue { $0.append(videoId) }
                }
            }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.view(.addTapped)) {
            $0.isAdding = true
        }
        await store.receive(\.addFinished) {
            $0.isAdding = false
        }
        await store.receive(\.delegate, .didAddVideos)
        #expect(added.value == ["video_2", "video_1", "video_watched"])
        #expect(dismissed.value)
    }

    @Test func partialFailureKeepsOnlyTheFailedSelected() async {
        var initialState = makeState()
        initialState.selectedVideoIds = ["video_1", "video_2"]
        let store = TestStore(initialState: initialState) {
            VideoPickerReducer()
        } withDependencies: {
            $0.playlistService.modifyCustomPlaylist = { _, _, _, videoId, _ in
                if videoId == "video_2" {
                    throw NSError(domain: "test", code: 0)
                }
            }
        }

        await store.send(.view(.addTapped)) {
            $0.isAdding = true
        }
        await store.receive(\.addFinished) {
            $0.isAdding = false
            $0.selectedVideoIds = ["video_2"]
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(String.localised("playlist.addVideosFailed \(1) \(2)", table: .videos))
            }
        }
    }

    @Test func loadingBuildsTheDisplayedItemsOnce() async {
        // Videos and downloads load concurrently; the gate holds the
        // downloads request until the videos have landed, so the two
        // results arrive in a fixed order.
        let downloadsGate = TestGate()
        let store = TestStore(initialState: makeState()) {
            VideoPickerReducer()
        } withDependencies: {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.paginatedVideos }
            $0.downloadService.getDownloads = { _, _, _, _, _, _ in
                await downloadsGate.wait()
                return TestFixtures.emptyDownloads
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
            $0.isLoadingDownloads = true
        }
        await store.receive(\.videosResult.success) {
            $0.videos = [TestFixtures.video1, TestFixtures.video2]
            $0.isLoading = false
            $0.hasLoaded = true
            // Newest first.
            $0.displayedItems = [.video(TestFixtures.video2), .video(TestFixtures.video1)]
        }
        downloadsGate.open()
        await store.receive(\.downloadsResult.success) {
            $0.isLoadingDownloads = false
        }
    }

    @Test func searchFiltersLocallyThenMergesServerResults() async {
        let clock = TestClock()
        var initialState = makeState()
        initialState.videos = [TestFixtures.video1, TestFixtures.video2]
        initialState.updateDisplayedItems()
        let store = TestStore(initialState: initialState) {
            VideoPickerReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.searchService.search = { _, _ in
                SearchResponse(
                    videoResults: [TestFixtures.watchedVideo],
                    channelResults: nil,
                    playlistResults: nil
                )
            }
        }

        await store.send(.binding(.set(\.searchQuery, "Video 1"))) {
            $0.searchQuery = "Video 1"
            $0.isSearching = true
            $0.displayedItems = [.video(TestFixtures.video1)]
        }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchResult.success) {
            $0.searchResults = [TestFixtures.watchedVideo]
            $0.isSearching = false
            $0.displayedItems = [.video(TestFixtures.watchedVideo), .video(TestFixtures.video1)]
        }
    }
}
