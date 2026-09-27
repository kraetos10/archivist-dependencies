import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import ArchivistFeatures

/// State-transition and effect coverage for `VideoDetailReducer`.
///
/// Playback goes through `PlayerClient`, so the play/stop/dismiss paths run
/// against an in-memory player here instead of `PlayerManager.shared` (which
/// would stand up a real `AVAudioSession`). The event loop itself is covered
/// by `VideoDetailPlayerEventsTests`.
@MainActor
@Suite(
    .serialized,
    .timeLimit(.minutes(1)),
    .dependencies {
        $0.defaultDatabase = try TubeData.shared.inMemoryDatabase()
        $0.playerClient = .noop
    }
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

    @Test func videoRefreshedReplacesTheVideoWhenItIsTheSameOne() async {
        let store = makeStore()
        let refreshed = TestFixtures.videoWithStream(TestFixtures.vp9Stream)

        await store.send(.videoRefreshed(refreshed)) {
            $0.video = refreshed
        }
    }

    /// The stale-response guard: after an in-place switch, the previous
    /// video's refresh must not put that video back on screen.
    @Test func videoRefreshedForAnotherVideoIsIgnored() async {
        let store = makeStore()

        await store.send(.videoRefreshed(TestFixtures.video2))
    }

    // MARK: - Comments

    @Test func commentsResultPopulatesCommentsAndClearsLoading() async {
        let store = makeStore { $0.isLoadingComments = true }

        await store.send(.commentsResult(videoId: "video_1", .success([TestFixtures.comment1]))) {
            $0.isLoadingComments = false
            $0.comments = [TestFixtures.comment1]
        }
    }

    @Test func commentsResultForAnotherVideoIsIgnored() async {
        let store = makeStore { $0.isLoadingComments = true }

        await store.send(.commentsResult(videoId: "video_2", .success([TestFixtures.comment1])))
    }

    @Test func commentsFailureClearsLoadingAndKeepsExistingComments() async {
        let store = makeStore {
            $0.isLoadingComments = true
            $0.comments = [TestFixtures.comment1]
        }

        await store.send(.commentsResult(videoId: "video_1", .failure(TestError.failed))) {
            $0.isLoadingComments = false
        }
    }

    @Test func commentsHeaderTapTogglesTheFullList() async {
        let store = makeStore()

        await store.send(.view(.commentsHeaderTapped)) {
            $0.showAllComments = true
        }
        await store.send(.view(.commentsHeaderTapped)) {
            $0.showAllComments = false
        }
    }

    // MARK: - Similar videos

    /// Already-watched videos are dropped: suggesting something the user has
    /// finished is the one thing the rail shouldn't do.
    @Test func similarResultFiltersOutWatchedVideos() async {
        let store = makeStore { $0.isLoadingSimilar = true }

        await store.send(
            .similarResult(
                videoId: "video_1",
                .success([TestFixtures.video2, TestFixtures.watchedVideo])
            )
        ) {
            $0.isLoadingSimilar = false
            $0.similarVideos = [TestFixtures.video2]
        }
    }

    @Test func similarResultForAnotherVideoIsIgnored() async {
        let store = makeStore { $0.isLoadingSimilar = true }

        await store.send(.similarResult(videoId: "video_2", .success([TestFixtures.video2])))
    }

    // MARK: - Switching video in place

    /// Loads started for the outgoing video are cancelled when the screen
    /// switches: the new video's loads restart with `cancelInFlight`, so a
    /// slow response for the old one never arrives.
    @Test func similarVideoTapCancelsTheOutgoingVideosLoads() async {
        let store = makeStore()
        store.dependencies.localVideoStorage.isDownloaded = { _ in false }
        store.dependencies.offlineMedia = OfflineMediaClient(
            localFileURL: { URL(filePath: "/tmp/\($0).mp4") },
            isCached: { _ in false }
        )
        store.dependencies.persistentDownloadManager = IdleDownloadManager()
        // Refresh and similar never answer; the test ends by skipping them.
        store.dependencies.videoService.getVideo = { _, _ in
            try await Task.never()
        }
        store.dependencies.videoService.getSimilar = { _, _ in
            try await Task.never()
        }
        // video_1's comments never answer; video_2's do at once.
        store.dependencies.videoService.getComments = { _, videoId in
            if videoId == "video_1" {
                try await Task.never()
            }
            return [TestFixtures.comment1]
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoadingComments = true
            $0.isLoadingSimilar = true
        }
        await store.send(.view(.similarVideoTapped(TestFixtures.video2))) {
            $0.video = TestFixtures.video2
            $0.isLoadingComments = true
            $0.isLoadingSimilar = true
        }
        // Only video_2's comments arrive. Had video_1's comments effect
        // survived, TestStore would fail on its unexpected action.
        await store.receive(\.commentsResult) {
            $0.isLoadingComments = false
            $0.comments = [TestFixtures.comment1]
        }
        await store.skipInFlightEffects()
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

    // MARK: - Downloads

    @Test func downloadProgressAndCompletionDriveTheDownloadState() async {
        let store = makeStore { $0.isDownloading = true }

        await store.send(.downloadProgressUpdated(videoId: "video_1", progress: 0.5)) {
            $0.downloadProgress = 0.5
        }
        await store.send(.downloadCompleted(videoId: "video_1")) {
            $0.isDownloading = false
            $0.isDownloaded = true
            $0.downloadProgress = 1.0
        }
    }

    /// An observer left over from the previous video must not mark this one
    /// downloaded — its offline file wouldn't exist, so playback would fail.
    @Test func downloadEventsForAnotherVideoAreIgnored() async {
        let store = makeStore()

        await store.send(.downloadProgressUpdated(videoId: "video_2", progress: 0.5))
        await store.send(.downloadCompleted(videoId: "video_2"))
        await store.send(.downloadFailed(videoId: "video_2", message: "boom"))
    }

    @Test func downloadFailureSurfacesTheMessageInAnAlert() async {
        let store = makeStore { $0.isDownloading = true }

        await store.send(.downloadFailed(videoId: "video_1", message: "no space left")) {
            $0.isDownloading = false
            $0.downloadError = "no space left"
            $0.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState("no space left")
            }
        }
    }

    @Test func deletingTheDownloadRemovesTheFileAndRowInAnEffect() async {
        let deleted = LockIsolated<[String]>([])
        let store = makeStore { $0.isDownloaded = true }
        store.dependencies.localVideoStorage.deleteVideo = { videoId in
            deleted.withValue { $0.append("file:\(videoId)") }
        }
        store.dependencies.deviceDownloadDatabase.deleteDownload = { videoId in
            deleted.withValue { $0.append("row:\(videoId)") }
        }

        await store.send(.view(.deleteDownloadTapped)) {
            $0.isDownloaded = false
        }
        await store.finish()
        expectNoDifference(deleted.value, ["file:video_1", "row:video_1"])
    }

    // MARK: - Playback

    @Test func playTappedStartsPlaybackAndReportsAFailedLoad() async {
        let requests = LockIsolated<[PlayerClient.PlaybackRequest]>([])
        let stops = LockIsolated(0)
        let (events, continuation) = AsyncStream<PlayerEvent>.makeStream()
        let store = makeStore(video: TestFixtures.videoWithMedia)
        store.dependencies.playerClient.startPlayback = { request in
            requests.withValue { $0.append(request) }
            return events
        }
        store.dependencies.playerClient.stop = { _ in
            stops.withValue { $0 += 1 }
        }

        await store.send(.view(.playTapped)) {
            $0.isPlaying = true
        }

        continuation.yield(.playbackFailed(videoId: "video_1"))
        await store.receive(\.playbackFailed) {
            $0.isPlaying = false
            $0.alert = AlertState {
                TextState(String.localised("video.playbackFailed.title", table: .videos))
            } actions: {
                ButtonState(action: .retryPlayback) {
                    TextState(String.localised("video.playbackFailed.retry", table: .videos))
                }
                ButtonState(role: .cancel, action: .dismissed) {
                    TextState(String.localised("generic.cancel", table: .generic))
                }
            } message: {
                TextState(String.localised("video.playbackFailed.message", table: .videos))
            }
        }
        continuation.finish()
        await store.finish()
        // The event could only arrive on the stream `startPlayback` returned.
        expectNoDifference(requests.value.map(\.videoId), ["video_1"])
        expectNoDifference(
            requests.value.first?.url,
            config.fullURL(for: "/media/video_1.mp4")
        )
        expectNoDifference(stops.value, 1)
    }

    /// The position is read in the same main-actor turn as the stop, so the
    /// save can't race `stop()` zeroing it.
    @Test func stopPlaybackSavesThePositionReadAtTheStop() async {
        let saved = LockIsolated<Int?>(nil)
        let store = makeStore { $0.isPlaying = true }
        store.dependencies.playerClient.stopReturningPosition = { _ in 42 }
        store.dependencies.videoService.setProgress = { _, _, position in
            saved.setValue(position)
        }

        await store.send(.view(.stopPlayback)) {
            $0.isPlaying = false
        }
        await store.finish()
        expectNoDifference(saved.value, 42)
    }

    @Test func dismissStopsSavesAndDismisses() async {
        let roles = LockIsolated<[PlayerSurfaceRole]>([])
        let dismissed = LockIsolated(false)
        let (saves, saveContinuation) = AsyncStream<Int>.makeStream()
        let store = makeStore { $0.isPlaying = true }
        store.dependencies.playerClient.setActivePlayerSurfaceRole = { role in
            roles.withValue { $0.append(role) }
        }
        store.dependencies.playerClient.stopReturningPosition = { _ in 30 }
        store.dependencies.videoService.setProgress = { _, _, position in
            saveContinuation.yield(position)
            saveContinuation.finish()
        }
        store.dependencies.dismiss = DismissEffect { dismissed.setValue(true) }

        await store.send(.view(.dismissTapped))
        await store.receive(\.delegate)
        await store.finish()

        // The save is detached so it outlives the screen; wait for it.
        var positions: [Int] = []
        for await position in saves { positions.append(position) }
        expectNoDifference(positions, [30])
        expectNoDifference(roles.value, [.fullDetail])
        #expect(dismissed.value)
    }

    /// The mini player's copy isn't presented by anyone, so it must not
    /// drive `dismiss()` — `DismissEffect`'s test value would fail if it did.
    @Test func dismissFromTheMiniPlayerDoesNotCallDismiss() async {
        let store = makeStore {
            $0.isPlaying = true
            $0.isHostedInMiniPlayer = true
        }

        await store.send(.view(.dismissTapped))
        await store.receive(\.delegate)
        await store.finish()
    }

    @Test func childSeekSeeksToTheFractionOfTheDuration() async {
        let seeks = LockIsolated<[Double]>([])
        let store = makeStore()
        store.dependencies.playerClient.duration = { 200 }
        store.dependencies.playerClient.seek = { seconds in
            seeks.withValue { $0.append(seconds) }
        }

        await store.send(.view(.childSeekRequested(0.5)))
        await store.finish()
        expectNoDifference(seeks.value, [100])
    }

    // MARK: - Auto-play countdown

    @Test func countdownTickCountsDownAndMirrorsIntoThePlayer() async {
        let mirrored = LockIsolated<[Int?]>([])
        let store = makeStore {
            $0.autoPlayCountdown = AutoPlayCountdown(
                nextVideo: TestFixtures.video2,
                consumesPlayNextQueue: false,
                remainingSeconds: 5
            )
        }
        store.dependencies.playerClient.setAutoPlayCountdown = { info in
            mirrored.withValue { $0.append(info?.remainingSeconds) }
        }

        await store.send(.autoPlayCountdownTick) {
            $0.autoPlayCountdown?.remainingSeconds = 4
        }
        await store.finish()
        await store.send(.autoPlayCountdownTick) {
            $0.autoPlayCountdown?.remainingSeconds = 3
        }
        await store.finish()
        expectNoDifference(mirrored.value, [4, 3])
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

/// A download manager with nothing in flight.
private struct IdleDownloadManager: PersistentDownloadManagerType {
    func startDownload(
        url: URL,
        videoId: String,
        title: String,
        expectedSize: Int64?,
        authHeaders: [String: String],
        thumbnailURL: URL?
    ) async {}

    func isDownloading(videoId: String) async -> Bool { false }

    func progress(for videoId: String) async -> Double { 0 }

    func observe(videoId: String) async -> AsyncStream<DownloadEvent> {
        AsyncStream { $0.finish() }
    }

    func activeDownloads() async -> [DeviceDownloadInfo] { [] }
}

private extension TestFixtures {
    /// A VP9 stream — anything distinguishable from `video1`'s nil streams.
    static let vp9Stream = VideoStream(
        type: "video",
        index: 0,
        codec: "vp9",
        width: 1920,
        height: 1080,
        bitrate: nil
    )

    /// `video1` with a server media path, so it can be played.
    static let videoWithMedia = VideoResponse(
        videoId: video1.videoId,
        title: video1.title,
        description: nil,
        category: nil,
        channel: video1.channel,
        published: video1.published,
        dateDownloaded: nil,
        vidLastRefresh: nil,
        vidThumbUrl: nil,
        vidType: nil,
        active: nil,
        mediaUrl: "/media/video_1.mp4",
        mediaSize: nil,
        player: nil,
        stats: nil,
        subtitles: nil,
        streams: nil,
        tags: nil,
        commentCount: nil
    )
}
