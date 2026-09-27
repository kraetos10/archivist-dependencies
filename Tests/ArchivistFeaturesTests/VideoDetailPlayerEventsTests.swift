import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

/// Covers `VideoDetailReducer.consumePlayerEvents`, the loop that replaced
/// the single-assignment closure slots on `PlayerManager`.
///
/// The point of the refactor is that every observer now sees every event and
/// filters by `videoId` itself, so the filtering is what these assert on: the
/// old design relied on "whoever assigned last wins", which is exactly how
/// CarPlay used to knock out the detail screen's progress saving.
///
/// Nothing here touches `PlayerManager.shared` — the streams are built by
/// hand. That's the other half of the win: this code is reachable from a test
/// without standing up an `AVAudioSession`.
///
/// Time-limited: two tests wait on a detached server write, and would hang
/// rather than fail if it never came.
@MainActor
@Suite(.dependencies, .timeLimit(.minutes(1)))
struct VideoDetailPlayerEventsTests {
    let config = TestFixtures.serverConfig

    // MARK: - Helpers

    /// Feeds `events` through the consumer and returns the actions it sent.
    private func run(
        _ events: [PlayerEvent],
        videoId: String = "video_1",
        videoService: VideoService = .testValue
    ) async -> [String] {
        let (stream, continuation) = AsyncStream<PlayerEvent>.makeStream()
        for event in events {
            continuation.yield(event)
        }
        continuation.finish()

        let sent = LockIsolated<[String]>([])
        await VideoDetailReducer.consumePlayerEvents(
            stream,
            videoId: videoId,
            config: config,
            videoService: videoService,
            send: Send { action in
                // Reduce to a name here: `Action` isn't `Sendable`, so it
                // can't be captured by the collector's closure.
                let name = tag(action)
                sent.withValue { $0.append(name) }
            }
        )
        return sent.value
    }

    /// A service whose completion writes (`setWatched`, then
    /// `deleteProgress`) finish the returned stream once both have run, so a
    /// test can wait for the detached write instead of racing it.
    private func completionRecordingService() -> (
        service: VideoService,
        written: AsyncStream<Void>,
        calls: LockIsolated<[String]>
    ) {
        let calls = LockIsolated<[String]>([])
        let (written, continuation) = AsyncStream<Void>.makeStream()
        var service = VideoService.testValue
        service.setWatched = { _, videoId, isWatched in
            calls.withValue { $0.append("setWatched(\(videoId), \(isWatched))") }
        }
        service.deleteProgress = { _, videoId in
            calls.withValue { $0.append("deleteProgress(\(videoId))") }
            continuation.finish()
        }
        return (service, written, calls)
    }

    // MARK: - Cache

    @Test func cacheCompletedForThisVideoMarksItCached() async {
        let sent = await run([.cacheCompleted(videoId: "video_1")])
        expectNoDifference(sent, ["cacheStatusChanged(true)"])
    }

    @Test func cacheCompletedForAnotherVideoIsIgnored() async {
        let sent = await run([.cacheCompleted(videoId: "video_2")])
        expectNoDifference(sent, [])
    }

    // MARK: - End of media

    @Test func playbackCompletedForThisVideoEndsPlayback() async {
        let recording = completionRecordingService()

        let sent = await run([.playbackCompleted(videoId: "video_1")], videoService: recording.service)

        // Detached so it outlives the effect; wait so it can't leak past
        // the test.
        for await _ in recording.written {}

        expectNoDifference(sent, ["videoPlaybackDidEnd"])
        expectNoDifference(
            recording.calls.value,
            ["setWatched(video_1, true)", "deleteProgress(video_1)"]
        )
    }

    /// The regression this guards: with a shared stream, a detail screen
    /// showing video_1 must not react to video_2 finishing in the background.
    /// `VideoService.testValue` fails the test if `setWatched` is reached.
    @Test func playbackCompletedForAnotherVideoIsIgnored() async {
        let sent = await run([.playbackCompleted(videoId: "video_2")])
        expectNoDifference(sent, [])
    }

    // MARK: - Progress saving

    @Test func pausedForThisVideoSavesThePositionCarriedInTheEvent() async {
        let saved = LockIsolated<[String]>([])
        let finished = AsyncStream<Void>.makeStream()

        var service = VideoService.testValue
        service.setProgress = { _, videoId, position in
            saved.withValue { $0.append("\(videoId)@\(position)") }
            finished.continuation.finish()
        }

        let sent = await run([.paused(videoId: "video_1", position: 42)], videoService: service)

        // The write is deliberately detached so it outlives the effect (see
        // `saveProgressDetached`), so wait for it rather than racing it.
        for await _ in finished.stream {}

        expectNoDifference(sent, [])
        expectNoDifference(saved.value, ["video_1@42"])
    }

    /// The event carries the position because delivery is asynchronous — by
    /// the time this runs, `PlayerManager.stop()` has already zeroed
    /// `currentTime`. Reading it live is what used to lose the final save.
    @Test func pausedForAnotherVideoDoesNotSaveProgress() async {
        let sent = await run([.paused(videoId: "video_2", position: 42)])
        expectNoDifference(sent, [])
    }

    @Test func pausedAtTheStartDoesNotSaveProgress() async {
        let sent = await run([.paused(videoId: "video_1", position: 0)])
        expectNoDifference(sent, [])
    }

    // MARK: - Transport

    @Test func transportRequestsReachTheStore() async {
        let sent = await run([.nextRequested, .previousRequested])
        expectNoDifference(sent, ["nextVideoRequested", "previousVideoRequested"])
    }

    /// The countdown card has its own short-lived subscription in
    /// `handleAutoPlayCountdownStarted`; the playback loop must leave those
    /// alone or a tap would be handled twice.
    @Test func countdownTapsAreLeftToTheCountdownEffect() async {
        let sent = await run([.autoPlayPlayNowTapped, .autoPlayCancelTapped])
        expectNoDifference(sent, [])
    }

    // MARK: - Ordering

    @Test func eventsAreHandledInOrder() async {
        let recording = completionRecordingService()

        let sent = await run(
            [
                .cacheCompleted(videoId: "video_1"),
                .nextRequested,
                .playbackCompleted(videoId: "video_1")
            ],
            videoService: recording.service
        )
        for await _ in recording.written {}

        expectNoDifference(
            sent,
            ["cacheStatusChanged(true)", "nextVideoRequested", "videoPlaybackDidEnd"]
        )
    }
}

/// Compact stand-in for `Action: Equatable`, which the project deliberately
/// doesn't conform to. Free function so it stays outside the suite's
/// main-actor isolation — `Send`'s closure is `@Sendable`.
private func tag(_ action: VideoDetailReducer.Action) -> String {
    switch action {
    case .view(.videoPlaybackDidEnd): "videoPlaybackDidEnd"
    case .view(.nextVideoRequested): "nextVideoRequested"
    case .view(.previousVideoRequested): "previousVideoRequested"
    case .view(.autoPlayCountdownPlayNowTapped): "autoPlayPlayNow"
    case .view(.autoPlayCountdownCancelTapped): "autoPlayCancel"
    case .cacheStatusChanged(let isCached): "cacheStatusChanged(\(isCached))"
    default: "unexpected"
    }
}
