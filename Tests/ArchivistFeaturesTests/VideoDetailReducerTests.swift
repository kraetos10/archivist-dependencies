import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchivistFeatures

/// State-transition coverage for `VideoDetailReducer`.
///
/// Scoped to the paths that don't reach `PlayerManager.shared`: touching it
/// from a test would construct the singleton and activate a real
/// `AVAudioSession`. The playback side is covered instead by
/// `VideoDetailPlayerEventsTests`, which drives the event stream directly.
@MainActor
@Suite(
    .serialized,
    .dependencies { $0.defaultDatabase = try TubeData.shared.inMemoryDatabase() }
)
struct VideoDetailReducerTests {
    let config = TestFixtures.serverConfig

    private func makeStore(
        video: VideoResponse = TestFixtures.video1,
        configureState: (inout VideoDetailReducer.State) -> Void = { _ in }
    ) -> TestStore<VideoDetailReducer.State, VideoDetailReducer.Action> {
        var state = VideoDetailReducer.State(serverConfig: config, video: video)
        configureState(&state)
        return TestStore(initialState: state) {
            VideoDetailReducer()
        }
    }

    // MARK: - Refresh

    @Test func videoRefreshedReplacesTheVideo() async {
        let store = makeStore()

        await store.send(.videoRefreshed(TestFixtures.video2)) {
            $0.video = TestFixtures.video2
        }
    }

    // MARK: - Comments

    @Test func commentsResultPopulatesCommentsAndClearsLoading() async {
        let store = makeStore { $0.isLoadingComments = true }

        await store.send(.commentsResult(.success([TestFixtures.comment1]))) {
            $0.isLoadingComments = false
            $0.comments = [TestFixtures.comment1]
        }
    }

    @Test func commentsFailureClearsLoadingAndKeepsExistingComments() async {
        let store = makeStore {
            $0.isLoadingComments = true
            $0.comments = [TestFixtures.comment1]
        }

        await store.send(.commentsResult(.failure(TestError.failed))) {
            $0.isLoadingComments = false
        }
    }

    @Test func videoChangedResetsCommentPaging() async {
        let store = makeStore {
            $0.showAllComments = true
            $0.currentCommentIndex = 4
        }

        await store.send(.view(.videoChanged)) {
            $0.showAllComments = false
            $0.currentCommentIndex = 0
        }
    }

    // MARK: - Similar videos

    /// Already-watched videos are dropped: suggesting something the user has
    /// finished is the one thing the rail shouldn't do.
    @Test func similarResultFiltersOutWatchedVideos() async {
        let store = makeStore { $0.isLoadingSimilar = true }

        await store.send(
            .similarResult(.success([TestFixtures.video2, TestFixtures.watchedVideo]))
        ) {
            $0.isLoadingSimilar = false
            $0.similarVideos = [TestFixtures.video2]
        }
    }

    // MARK: - Watched toggle

    @Test func toggleWatchedMarksTheVideoWatchedOnSuccess() async {
        let store = makeStore()
        store.dependencies.videoService.setWatched = { _, _, _ in }
        store.dependencies.videoService.deleteProgress = { _, _ in }

        await store.send(.view(.toggleWatchedTapped))
        await store.receive(\.watchedToggleResult) {
            $0.watchedOverride = true
        }
    }

    @Test func toggleWatchedLeavesStateAloneOnFailure() async {
        let store = makeStore()
        store.dependencies.videoService.setWatched = { _, _, _ in throw TestError.failed }

        await store.send(.view(.toggleWatchedTapped))
        await store.receive(\.watchedToggleResult)
    }

    @Test func toggleWatchedOnAWatchedVideoMarksItUnwatched() async {
        let store = makeStore(video: TestFixtures.watchedVideo)
        store.dependencies.videoService.setWatched = { _, _, isWatched in
            #expect(isWatched == false)
        }

        await store.send(.view(.toggleWatchedTapped))
        await store.receive(\.watchedToggleResult) {
            $0.watchedOverride = false
        }
    }

    // MARK: - Cache status

    @Test func cacheStatusChangedUpdatesTheCachedFlag() async {
        let store = makeStore()

        await store.send(.cacheStatusChanged(true)) {
            $0.isCached = true
        }
    }

    // MARK: - Download progress

    @Test func downloadProgressAndCompletionDriveTheDownloadState() async {
        let store = makeStore { $0.isDownloading = true }

        await store.send(.downloadProgressUpdated(0.5)) {
            $0.downloadProgress = 0.5
        }
        await store.send(.downloadCompleted) {
            $0.isDownloading = false
            $0.isDownloaded = true
            $0.downloadProgress = 1.0
        }
    }

    @Test func downloadFailureSurfacesTheMessageInAnAlert() async {
        let store = makeStore { $0.isDownloading = true }

        await store.send(.downloadFailed("no space left")) {
            $0.isDownloading = false
            $0.downloadError = "no space left"
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState("no space left")
            }
        }
    }

    // MARK: - Auto-play countdown

    @Test func countdownTickCountsDown() async {
        let store = makeStore {
            $0.autoPlayCountdown = AutoPlayCountdown(
                nextVideo: TestFixtures.video2,
                consumesPlayNextQueue: false,
                remainingSeconds: 5
            )
        }

        await store.send(.autoPlayCountdownTick) {
            $0.autoPlayCountdown?.remainingSeconds = 4
        }
        await store.send(.autoPlayCountdownTick) {
            $0.autoPlayCountdown?.remainingSeconds = 3
        }
    }

    @Test func countdownTickWithoutACountdownIsANoOp() async {
        let store = makeStore()

        await store.send(.autoPlayCountdownTick)
    }

    // MARK: - Description

    @Test func toggleDescriptionFlipsExpansion() async {
        let store = makeStore()

        await store.send(.view(.toggleDescription)) {
            $0.isDescriptionExpanded = true
        }
        await store.send(.view(.toggleDescription)) {
            $0.isDescriptionExpanded = false
        }
    }
}

private enum TestError: Error {
    case failed
}
