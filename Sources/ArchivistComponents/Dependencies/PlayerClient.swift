#if !os(watchOS)
import Dependencies
import Foundation

/// Dependency wrapper around `PlayerManager.shared`, so reducers and
/// coordinators drive playback without touching the singleton directly.
///
/// Every endpoint is `@MainActor`, matching `PlayerManager`. From a TCA
/// `.run` effect, `await` a single call — or, when several operations must
/// happen in one main-actor hop (subscribe → stop → load, read → stop),
/// call them synchronously inside one `await MainActor.run { … }`.
///
/// Hand-written rather than `@DependencyClient`: `ArchivistComponents` does
/// not depend on `DependenciesMacros`.
public struct PlayerClient: Sendable {
    /// Everything needed to start a video in one main-actor hop.
    public struct PlaybackRequest: Sendable {
        public var url: URL
        public var startPosition: Double?
        public var videoId: String
        public var expectedSize: Int64?
        /// Now-playing metadata (overlay title row, Control Center). `nil`
        /// leaves the current metadata untouched.
        public var metadata: PlayerManager.NowPlayingMetadata?
        /// Stop the outgoing video first, keeping any fullscreen player up
        /// (auto-advance / play-next). The event stream is subscribed
        /// *before* the stop, so the outgoing `.paused` still reaches it.
        public var replacesCurrent: Bool
        /// New value for `PlayerManager.canGoPrevious`; `nil` leaves it.
        public var canGoPrevious: Bool?

        public init(
            url: URL,
            startPosition: Double?,
            videoId: String,
            expectedSize: Int64? = nil,
            metadata: PlayerManager.NowPlayingMetadata? = nil,
            replacesCurrent: Bool = false,
            canGoPrevious: Bool? = nil
        ) {
            self.url = url
            self.startPosition = startPosition
            self.videoId = videoId
            self.expectedSize = expectedSize
            self.metadata = metadata
            self.replacesCurrent = replacesCurrent
            self.canGoPrevious = canGoPrevious
        }
    }

    /// A consistent read of the player's state, taken in one main-actor hop.
    public struct Snapshot: Sendable, Equatable {
        public var videoId: String?
        public var isPlaying: Bool
        public var currentTime: Double
        /// `effectiveDuration` at the time of the read.
        public var duration: Double

        public init(
            videoId: String?,
            isPlaying: Bool,
            currentTime: Double,
            duration: Double
        ) {
            self.videoId = videoId
            self.isPlaying = isPlaying
            self.currentTime = currentTime
            self.duration = duration
        }
    }

    // MARK: Events

    /// A fresh, independent subscription to `PlayerManager.events`.
    public var events: @MainActor @Sendable () -> AsyncStream<PlayerEvent>
    /// Subscribes only if `videoId` is the one currently playing — adopting
    /// in-flight playback (PiP restore) without reloading. `nil` otherwise.
    public var eventsIfPlaying: @MainActor @Sendable (_ videoId: String) -> AsyncStream<PlayerEvent>?

    // MARK: Loading

    /// Subscribe, optionally stop the outgoing video, load, and set the
    /// current video ID and metadata — atomically. Returns the subscription.
    public var startPlayback: @MainActor @Sendable (_ request: PlaybackRequest) -> AsyncStream<PlayerEvent>
    /// Raw `PlayerManager.load`. Prefer `startPlayback`.
    public var load: @MainActor @Sendable (
        _ url: URL,
        _ startPosition: Double?,
        _ videoId: String?,
        _ expectedSize: Int64?
    ) -> Void

    // MARK: Transport

    /// `PlayerManager.stop(dismissFullscreen:)`.
    public var stop: @MainActor @Sendable (_ dismissFullscreen: Bool) -> Void
    /// Reads `currentTime`, then stops, in the same main-actor turn. Use for
    /// the final progress save: reading and stopping in separate hops races
    /// `stop()`, which zeroes `currentTime`.
    public var stopReturningPosition: @MainActor @Sendable (_ dismissFullscreen: Bool) -> Double
    public var pause: @MainActor @Sendable () -> Void
    public var resume: @MainActor @Sendable () -> Void
    public var togglePlayPause: @MainActor @Sendable () -> Void
    public var seek: @MainActor @Sendable (_ seconds: Double) -> Void
    public var skipForward: @MainActor @Sendable (_ seconds: Double) -> Void
    public var skipBackward: @MainActor @Sendable (_ seconds: Double) -> Void

    // MARK: State reads

    public var snapshot: @MainActor @Sendable () -> Snapshot
    public var currentTime: @MainActor @Sendable () -> Double
    public var duration: @MainActor @Sendable () -> Double
    /// `duration`, falling back to the metadata duration until libvlc reports one.
    public var effectiveDuration: @MainActor @Sendable () -> Double
    public var isPlaying: @MainActor @Sendable () -> Bool
    public var currentVideoID: @MainActor @Sendable () -> String?

    // MARK: State writes

    public var setCurrentVideoID: @MainActor @Sendable (_ videoId: String?) -> Void
    public var setNowPlayingMetadata: @MainActor @Sendable (_ metadata: PlayerManager.NowPlayingMetadata?) -> Void
    public var activePlayerSurfaceRole: @MainActor @Sendable () -> PlayerSurfaceRole
    /// Set *before* publishing a mini-player request, so the right host
    /// adopts the VLC surface as it mounts.
    public var setActivePlayerSurfaceRole: @MainActor @Sendable (_ role: PlayerSurfaceRole) -> Void
    /// Mirror of the VideoDetail auto-play countdown for the fullscreen VC.
    public var setAutoPlayCountdown: @MainActor @Sendable (_ info: AutoPlayCountdownInfo?) -> Void
    public var setCanGoPrevious: @MainActor @Sendable (_ canGoPrevious: Bool) -> Void

    // MARK: Speed

    public var playbackSpeed: @MainActor @Sendable () -> Float
    /// Saves the speed for later videos and applies it to this one.
    public var setPlaybackSpeed: @MainActor @Sendable (_ speed: Float) -> Void
    /// Temporary rate (tvOS press-and-hold), not saved.
    public var setPlaybackRate: @MainActor @Sendable (_ rate: Float) -> Void
    public var restorePlaybackSpeed: @MainActor @Sendable () -> Void

    public init(
        events: @escaping @MainActor @Sendable () -> AsyncStream<PlayerEvent>,
        eventsIfPlaying: @escaping @MainActor @Sendable (_ videoId: String) -> AsyncStream<PlayerEvent>?,
        startPlayback: @escaping @MainActor @Sendable (_ request: PlaybackRequest) -> AsyncStream<PlayerEvent>,
        load: @escaping @MainActor @Sendable (
            _ url: URL,
            _ startPosition: Double?,
            _ videoId: String?,
            _ expectedSize: Int64?
        ) -> Void,
        stop: @escaping @MainActor @Sendable (_ dismissFullscreen: Bool) -> Void,
        stopReturningPosition: @escaping @MainActor @Sendable (_ dismissFullscreen: Bool) -> Double,
        pause: @escaping @MainActor @Sendable () -> Void,
        resume: @escaping @MainActor @Sendable () -> Void,
        togglePlayPause: @escaping @MainActor @Sendable () -> Void,
        seek: @escaping @MainActor @Sendable (_ seconds: Double) -> Void,
        skipForward: @escaping @MainActor @Sendable (_ seconds: Double) -> Void,
        skipBackward: @escaping @MainActor @Sendable (_ seconds: Double) -> Void,
        snapshot: @escaping @MainActor @Sendable () -> Snapshot,
        currentTime: @escaping @MainActor @Sendable () -> Double,
        duration: @escaping @MainActor @Sendable () -> Double,
        effectiveDuration: @escaping @MainActor @Sendable () -> Double,
        isPlaying: @escaping @MainActor @Sendable () -> Bool,
        currentVideoID: @escaping @MainActor @Sendable () -> String?,
        setCurrentVideoID: @escaping @MainActor @Sendable (_ videoId: String?) -> Void,
        setNowPlayingMetadata: @escaping @MainActor @Sendable (_ metadata: PlayerManager.NowPlayingMetadata?) -> Void,
        activePlayerSurfaceRole: @escaping @MainActor @Sendable () -> PlayerSurfaceRole,
        setActivePlayerSurfaceRole: @escaping @MainActor @Sendable (_ role: PlayerSurfaceRole) -> Void,
        setAutoPlayCountdown: @escaping @MainActor @Sendable (_ info: AutoPlayCountdownInfo?) -> Void,
        setCanGoPrevious: @escaping @MainActor @Sendable (_ canGoPrevious: Bool) -> Void,
        playbackSpeed: @escaping @MainActor @Sendable () -> Float,
        setPlaybackSpeed: @escaping @MainActor @Sendable (_ speed: Float) -> Void,
        setPlaybackRate: @escaping @MainActor @Sendable (_ rate: Float) -> Void,
        restorePlaybackSpeed: @escaping @MainActor @Sendable () -> Void
    ) {
        self.events = events
        self.eventsIfPlaying = eventsIfPlaying
        self.startPlayback = startPlayback
        self.load = load
        self.stop = stop
        self.stopReturningPosition = stopReturningPosition
        self.pause = pause
        self.resume = resume
        self.togglePlayPause = togglePlayPause
        self.seek = seek
        self.skipForward = skipForward
        self.skipBackward = skipBackward
        self.snapshot = snapshot
        self.currentTime = currentTime
        self.duration = duration
        self.effectiveDuration = effectiveDuration
        self.isPlaying = isPlaying
        self.currentVideoID = currentVideoID
        self.setCurrentVideoID = setCurrentVideoID
        self.setNowPlayingMetadata = setNowPlayingMetadata
        self.activePlayerSurfaceRole = activePlayerSurfaceRole
        self.setActivePlayerSurfaceRole = setActivePlayerSurfaceRole
        self.setAutoPlayCountdown = setAutoPlayCountdown
        self.setCanGoPrevious = setCanGoPrevious
        self.playbackSpeed = playbackSpeed
        self.setPlaybackSpeed = setPlaybackSpeed
        self.setPlaybackRate = setPlaybackRate
        self.restorePlaybackSpeed = restorePlaybackSpeed
    }
}

// MARK: - Labelled conveniences

extension PlayerClient {
    /// Stop playback; dismisses any fullscreen player by default.
    @MainActor
    public func stop(dismissFullscreen: Bool = true) {
        self.stop(dismissFullscreen)
    }

    /// Atomic read-then-stop. See the `stopReturningPosition` endpoint.
    @MainActor
    public func stopReturningPosition(dismissFullscreen: Bool = true) -> Double {
        self.stopReturningPosition(dismissFullscreen)
    }

    @MainActor
    public func seek(to seconds: Double) {
        self.seek(seconds)
    }

    @MainActor
    public func skipForward(by seconds: Double = 10) {
        self.skipForward(seconds)
    }

    @MainActor
    public func skipBackward(by seconds: Double = 10) {
        self.skipBackward(seconds)
    }
}

// MARK: - Live

extension PlayerClient: DependencyKey {
    public static var liveValue: PlayerClient {
        PlayerClient(
            events: { PlayerManager.shared.events },
            eventsIfPlaying: { videoId in
                let manager = PlayerManager.shared
                guard manager.currentVideoID == videoId, manager.isPlaying else { return nil }
                return manager.events
            },
            startPlayback: { liveStartPlayback($0) },
            load: { url, startPosition, videoId, expectedSize in
                PlayerManager.shared.load(
                    url: url,
                    startPosition: startPosition,
                    videoId: videoId,
                    expectedSize: expectedSize
                )
            },
            stop: { dismissFullscreen in
                PlayerManager.shared.stop(dismissFullscreen: dismissFullscreen)
            },
            stopReturningPosition: { dismissFullscreen in
                let manager = PlayerManager.shared
                let position = manager.currentTime
                manager.stop(dismissFullscreen: dismissFullscreen)
                return position
            },
            pause: { PlayerManager.shared.pause() },
            resume: { PlayerManager.shared.resume() },
            togglePlayPause: { PlayerManager.shared.togglePlayPause() },
            seek: { PlayerManager.shared.seekTo($0) },
            skipForward: { PlayerManager.shared.skipForward($0) },
            skipBackward: { PlayerManager.shared.skipBackward($0) },
            snapshot: {
                let manager = PlayerManager.shared
                return Snapshot(
                    videoId: manager.currentVideoID,
                    isPlaying: manager.isPlaying,
                    currentTime: manager.currentTime,
                    duration: manager.effectiveDuration
                )
            },
            currentTime: { PlayerManager.shared.currentTime },
            duration: { PlayerManager.shared.duration },
            effectiveDuration: { PlayerManager.shared.effectiveDuration },
            isPlaying: { PlayerManager.shared.isPlaying },
            currentVideoID: { PlayerManager.shared.currentVideoID },
            setCurrentVideoID: { PlayerManager.shared.currentVideoID = $0 },
            setNowPlayingMetadata: { PlayerManager.shared.currentMetadata = $0 },
            activePlayerSurfaceRole: { PlayerManager.shared.activePlayerSurfaceRole },
            setActivePlayerSurfaceRole: { PlayerManager.shared.activePlayerSurfaceRole = $0 },
            setAutoPlayCountdown: { PlayerManager.shared.autoPlayCountdown = $0 },
            setCanGoPrevious: { PlayerManager.shared.canGoPrevious = $0 },
            playbackSpeed: { PlayerManager.shared.playbackSpeed },
            setPlaybackSpeed: { PlayerManager.shared.setPlaybackSpeed($0) },
            setPlaybackRate: { PlayerManager.shared.setPlaybackRate($0) },
            restorePlaybackSpeed: { PlayerManager.shared.restorePlaybackSpeed() }
        )
    }

    /// Subscribe → (stop) → load → identify, all in one main-actor turn.
    @MainActor
    private static func liveStartPlayback(_ request: PlaybackRequest) -> AsyncStream<PlayerEvent> {
        let manager = PlayerManager.shared
        // Subscribe first so nothing emitted by stop/load is missed.
        let events = manager.events
        if request.replacesCurrent {
            manager.stop(dismissFullscreen: false)
        }
        if let canGoPrevious = request.canGoPrevious {
            manager.canGoPrevious = canGoPrevious
        }
        manager.load(
            url: request.url,
            startPosition: request.startPosition,
            videoId: request.videoId,
            expectedSize: request.expectedSize
        )
        manager.currentVideoID = request.videoId
        if let metadata = request.metadata {
            manager.currentMetadata = metadata
        }
        return events
    }

    /// Every endpoint reports an issue and returns a placeholder. Override
    /// the endpoints a test exercises.
    public static var testValue: PlayerClient {
        PlayerClient(
            events: { unimplementedCall("events", placeholder: .finished) },
            eventsIfPlaying: { _ in unimplementedCall("eventsIfPlaying", placeholder: nil) },
            startPlayback: { _ in unimplementedCall("startPlayback", placeholder: .finished) },
            load: { _, _, _, _ in unimplementedCall("load", placeholder: ()) },
            stop: { _ in unimplementedCall("stop", placeholder: ()) },
            stopReturningPosition: { _ in unimplementedCall("stopReturningPosition", placeholder: 0) },
            pause: { unimplementedCall("pause", placeholder: ()) },
            resume: { unimplementedCall("resume", placeholder: ()) },
            togglePlayPause: { unimplementedCall("togglePlayPause", placeholder: ()) },
            seek: { _ in unimplementedCall("seek", placeholder: ()) },
            skipForward: { _ in unimplementedCall("skipForward", placeholder: ()) },
            skipBackward: { _ in unimplementedCall("skipBackward", placeholder: ()) },
            snapshot: { unimplementedCall("snapshot", placeholder: .idle) },
            currentTime: { unimplementedCall("currentTime", placeholder: 0) },
            duration: { unimplementedCall("duration", placeholder: 0) },
            effectiveDuration: { unimplementedCall("effectiveDuration", placeholder: 0) },
            isPlaying: { unimplementedCall("isPlaying", placeholder: false) },
            currentVideoID: { unimplementedCall("currentVideoID", placeholder: nil) },
            setCurrentVideoID: { _ in unimplementedCall("setCurrentVideoID", placeholder: ()) },
            setNowPlayingMetadata: { _ in unimplementedCall("setNowPlayingMetadata", placeholder: ()) },
            activePlayerSurfaceRole: { unimplementedCall("activePlayerSurfaceRole", placeholder: .fullDetail) },
            setActivePlayerSurfaceRole: { _ in unimplementedCall("setActivePlayerSurfaceRole", placeholder: ()) },
            setAutoPlayCountdown: { _ in unimplementedCall("setAutoPlayCountdown", placeholder: ()) },
            setCanGoPrevious: { _ in unimplementedCall("setCanGoPrevious", placeholder: ()) },
            playbackSpeed: { unimplementedCall("playbackSpeed", placeholder: 1) },
            setPlaybackSpeed: { _ in unimplementedCall("setPlaybackSpeed", placeholder: ()) },
            setPlaybackRate: { _ in unimplementedCall("setPlaybackRate", placeholder: ()) },
            restorePlaybackSpeed: { unimplementedCall("restorePlaybackSpeed", placeholder: ()) }
        )
    }

    /// Silent no-op player for previews.
    public static var previewValue: PlayerClient { .noop }

    /// A player that does nothing: streams finish immediately, reads return
    /// idle values.
    public static var noop: PlayerClient {
        PlayerClient(
            events: { .finished },
            eventsIfPlaying: { _ in nil },
            startPlayback: { _ in .finished },
            load: { _, _, _, _ in },
            stop: { _ in },
            stopReturningPosition: { _ in 0 },
            pause: {},
            resume: {},
            togglePlayPause: {},
            seek: { _ in },
            skipForward: { _ in },
            skipBackward: { _ in },
            snapshot: { .idle },
            currentTime: { 0 },
            duration: { 0 },
            effectiveDuration: { 0 },
            isPlaying: { false },
            currentVideoID: { nil },
            setCurrentVideoID: { _ in },
            setNowPlayingMetadata: { _ in },
            activePlayerSurfaceRole: { .fullDetail },
            setActivePlayerSurfaceRole: { _ in },
            setAutoPlayCountdown: { _ in },
            setCanGoPrevious: { _ in },
            playbackSpeed: { 1 },
            setPlaybackSpeed: { _ in },
            setPlaybackRate: { _ in },
            restorePlaybackSpeed: {}
        )
    }
}

extension PlayerClient.Snapshot {
    /// Nothing loaded.
    public static var idle: Self {
        Self(
            videoId: nil,
            isPlaying: false,
            currentTime: 0,
            duration: 0
        )
    }
}

extension AsyncStream where Element == PlayerEvent {
    /// A stream that has already finished.
    fileprivate static var finished: Self {
        AsyncStream { $0.finish() }
    }
}

private func unimplementedCall<Value>(
    _ endpoint: String,
    placeholder: Value
) -> Value {
    reportIssue("Unimplemented: 'PlayerClient.\(endpoint)'")
    return placeholder
}

extension DependencyValues {
    /// Playback control, backed by `PlayerManager.shared` in the live app.
    public var playerClient: PlayerClient {
        get { self[PlayerClient.self] }
        set { self[PlayerClient.self] = newValue }
    }
}
#endif
