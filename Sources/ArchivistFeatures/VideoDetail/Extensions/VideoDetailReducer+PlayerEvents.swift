import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension VideoDetailReducer {
    /// Drives the feature from `PlayerManager`'s broadcast event stream for
    /// as long as the owning effect lives.
    ///
    /// This replaces the closure slots the reducer used to install on
    /// `PlayerManager` (`onPause`, `onPlaybackCompleted`, `onCacheCompleted`,
    /// …). Those had two problems this fixes:
    ///
    /// 1. They were single-assignment on a singleton, so the CarPlay
    ///    coordinator installing its own `onPause` silently disabled this
    ///    feature's progress save until the app restarted.
    /// 2. Each one reached back into the store with a detached
    ///    `Task { @MainActor in await send(…) }`. That escaped the effect
    ///    system: the sends could not be cancelled, still landed after the
    ///    screen was dismissed, and made the feature untestable — a
    ///    `TestStore` sees them as unexpected actions.
    ///
    /// Every `send` now happens inside the caller's `.run` effect, so
    /// cancelling that effect (dismiss, or `cancelInFlight` on the next
    /// video) terminates the stream and stops the sends.
    ///
    /// Declared `static` so the caller's `@Sendable` effect closure doesn't
    /// have to capture the non-`Sendable` reducer struct — the same reason
    /// `periodicProgressSaveTask` is static.
    ///
    /// - Parameter videoId: Events are broadcast for *every* video, so each
    ///   payload is filtered against this before it's acted on. Without the
    ///   filter, a stale observer would save the wrong video's progress.
    static func consumePlayerEvents(
        _ events: AsyncStream<PlayerEvent>,
        videoId: String,
        config: ServerConfig,
        videoService: VideoService,
        send: Send<Action>
    ) async {
        for await event in events {
            switch event {
            case .paused(let eventVideoId, let position):
                guard eventVideoId == videoId, position > 0 else { continue }
                saveProgressDetached(
                    config: config,
                    videoId: videoId,
                    position: position,
                    videoService: videoService
                )

            case .playbackCompleted(let eventVideoId):
                guard eventVideoId == videoId else { continue }
                // Send first so auto-advance isn't gated on a network
                // round-trip, then record completion out of band.
                await send(.view(.videoPlaybackDidEnd))
                markWatchedDetached(
                    config: config,
                    videoId: videoId,
                    videoService: videoService
                )

            case .cacheCompleted(let completedId):
                guard completedId == videoId else { continue }
                await send(.cacheStatusChanged(true))

            case .nextRequested:
                await send(.view(.nextVideoRequested))

            case .previousRequested:
                await send(.view(.previousVideoRequested))

            case .autoPlayPlayNowTapped, .autoPlayCancelTapped:
                // Owned by the countdown effect, which subscribes
                // separately for the lifetime of a single countdown.
                continue
            }
        }
    }

    /// Fire-and-forget final progress save.
    ///
    /// Detached on purpose. Auto-advance stops the outgoing video — which
    /// emits `.paused` — and then immediately cancels the playback effect
    /// via `cancelInFlight`, so a structured child task would be cancelled
    /// before the write reached the server, losing the resume position.
    /// Nothing is sent into the store here, so this stays invisible to
    /// `TestStore` and doesn't reintroduce the escaping-`send` problem.
    private static func saveProgressDetached(
        config: ServerConfig,
        videoId: String,
        position: Int,
        videoService: VideoService
    ) {
        Task.detached {
            try? await videoService.setProgress(
                config: config,
                videoId: videoId,
                position: position
            )
        }
    }

    /// Fire-and-forget completion write, detached for the same reason as
    /// `saveProgressDetached`: end-of-media can arrive while the detail
    /// screen is already gone (the video finished in PiP), and the watched
    /// flag still has to reach the server.
    private static func markWatchedDetached(
        config: ServerConfig,
        videoId: String,
        videoService: VideoService
    ) {
        Task.detached {
            try? await videoService.setWatched(
                config: config,
                videoId: videoId,
                isWatched: true
            )
            // Reset stored playtime so the finished video starts from the
            // beginning next time rather than resuming into the final
            // moments.
            try? await videoService.deleteProgress(
                config: config,
                videoId: videoId
            )
        }
    }
}
