import ArchivistNetworking
import AVFoundation
import AVKit
import Network
import SwiftUI
import SystemConfiguration
#if !os(tvOS) && !os(watchOS)
import UIKit
#endif
#if canImport(Sharing)
import Sharing
#endif
#if canImport(VLCKit) && !os(tvOS) && !os(watchOS)
import VLCKit
#endif
#if os(iOS) || os(tvOS)
import VLCPlayerCore
#endif

/// Identifies which on-screen container should host the persistent player
/// surface. Used to prevent the mini and expanded video detail from racing
/// to reparent the same surface during transitions.
public enum PlayerSurfaceRole: Sendable, Equatable {
    case fullDetail
    case mini
}

#if !os(watchOS)
@Observable
@MainActor
public final class PlayerManager: NSObject {
    public static let shared = PlayerManager()

    public struct NowPlayingMetadata: Sendable {
        public let title: String
        public let artist: String
        public let duration: Double
        public let artworkURL: URL?
        public let channelThumbURL: URL?
        public let authHeaders: [String: String]

        public init(
            title: String,
            artist: String,
            duration: Double,
            artworkURL: URL?,
            channelThumbURL: URL? = nil,
            authHeaders: [String: String]
        ) {
            self.title = title
            self.artist = artist
            self.duration = duration
            self.artworkURL = artworkURL
            self.channelThumbURL = channelThumbURL
            self.authHeaders = authHeaders
        }
    }

    public private(set) var backend: (any PlayerBackend)?

    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0
    public var currentVideoID: String?
    public var isInPiP = false
    public var isVLCFullscreen = false
    public var activePiPDelegate: AnyObject?

    public var supportsPiP: Bool { backend is PlaybackServiceBackend }
    public var isUsingFallbackPlayer: Bool { backend is PlaybackServiceBackend }
    public var isUsingVLC: Bool { backend is PlaybackServiceBackend }

    #if !os(tvOS)
    @ObservationIgnored private let nowPlayingService = NowPlayingService()
    #endif

    #if canImport(VLCKit) && !os(watchOS)
    /// Persistent VLC player surface owned by `PlaybackServiceBackend`.
    /// Created on first `load()` and reused across containers — reparenting
    /// the same `UIView` keeps libvlc's media player alive, so transitions
    /// between the mini-player and the full video detail don't restart
    /// playback.
    public var persistentVLCPlayerView: UIView? {
        (backend as? PlaybackServiceBackend)?.playerView
    }
    #endif

    /// Identifies which container is currently allowed to host the persistent
    /// player surface. Without this, two wrapper instances briefly co-exist
    /// during a mini ↔ full transition and they'd fight over reparenting the
    /// surface, leaving the wrong container with the player.
    public var activePlayerSurfaceRole: PlayerSurfaceRole = .fullDetail

    /// File URL stashed by the prebuffer cache callback while we're in PiP.
    /// Swapping mid-PiP would tear the rendering pipeline down and restart
    /// from zero, so we defer until PiP ends — `applyPendingCacheSwap` is
    /// invoked from the PiP teardown path on the player view.
    @ObservationIgnored
    var pendingCacheSwapURL: URL?

    #if !os(tvOS)
    private var interruptionObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var orientationObserver: NSObjectProtocol?
    #endif

    #if !os(tvOS) && !os(watchOS)
    /// Background task that keeps the app alive between videos so the
    /// auto-play transition can complete (fetch next video + start playback).
    private var playbackTransitionTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    public var onPause: (() -> Void)?
    /// Fires when the player reaches end-of-media on its own (i.e. the video
    /// played through to the end, distinct from a user-initiated pause/stop).
    /// Set by `VideoDetailReducer` so we can mark the video as watched on
    /// the server even when the detail screen has been dismissed (e.g. the
    /// user is in PiP and the video finishes there).
    public var onPlaybackCompleted: (() -> Void)?
    /// Fires on the main actor when the parallel prebuffer download finishes
    /// and the backend has swapped to the local file. Useful for UI surfaces
    /// like the video detail row that show a "cached" indicator.
    public var onCacheCompleted: ((String) -> Void)?
    /// User tapped "next" on the transport overlay. Wired by the VideoDetail
    /// reducer to the same auto-advance rules end-of-media uses.
    public var onNextRequested: (() -> Void)?
    /// User tapped "previous" on the transport overlay. No-op while
    /// `canGoPrevious` is false.
    public var onPreviousRequested: (() -> Void)?
    /// True when a history of previously-played videos exists, so the
    /// "previous" transport button should be enabled.
    public var canGoPrevious: Bool = false
    /// Fires when the user taps "restore from PiP" but the source detail
    /// screen has already been dismissed. Wired at app start to push the
    /// VideoDetail screen back onto the navigation stack so the player
    /// has somewhere to surface. Receives the currently-playing videoId.
    public var onPiPRestoreRequested: ((String) -> Void)?

    /// Wall-clock timestamp of the last PiP-restore-driven detail-screen
    /// remount. Used to suppress immediate re-restores: when a user
    /// dismisses a freshly-restored detail screen, the dismiss handler
    /// kicks PiP again, which can race into PiP-end and re-fire restore,
    /// looping the screen open. Cooldown breaks that cycle while leaving
    /// normal "PiP for hours, restore later" untouched.
    private var lastPiPRestoreAt: Date?
    private let pipRestoreCooldown: TimeInterval = 3.0

    public var currentMetadata: NowPlayingMetadata? {
        didSet {
            #if !os(tvOS)
            if let metadata = currentMetadata {
                nowPlayingService.setupRemoteCommands()
                nowPlayingService.configure(
                    title: metadata.title,
                    artist: metadata.artist,
                    duration: metadata.duration,
                    currentTime: currentTime,
                    isPlaying: isPlaying,
                    artworkURL: metadata.artworkURL,
                    authHeaders: metadata.authHeaders
                )
            }
            #endif
        }
    }

    private override init() {
        super.init()
        #if !os(tvOS)
        setupBackgroundPlayback()
        #endif
    }

    #if !os(tvOS)
    private func setupBackgroundPlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let typeValue = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = info?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                guard let self else { return }
                guard let typeValue,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
                }

                switch type {
                case .began:
                    self.isPlaying = false
                case .ended:
                    if let optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.backend?.play()
                            self.isPlaying = true
                        }
                    }
                @unknown default:
                    break
                }
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            try? AVAudioSession.sharedInstance().setActive(true)
            // VLCKit's video output occasionally loses its window/layer
            // binding while the app is backgrounded — audio keeps playing
            // but the picture comes back black. Force a re-bind of the
            // rendering pipeline against the current host window.
            MainActor.assumeIsolated {
                self?.refreshVideoOutput()
            }
        }

        // Device rotation triggers a host bounds change, but VLCKit's
        // rendering layer doesn't auto-rebind to the new geometry —
        // audio keeps playing while the picture goes black. Nudge VLC
        // (pause+play+seek) on every rotation so the layer reattaches
        // to the resized drawable.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Tiny delay so the bounds change has fully propagated
            // through the SwiftUI layout pass before we hit VLC.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                self?.refreshVideoOutput()
            }
        }
    }

    /// Forward to the active backend's `refreshDrawable`. Wired to the
    /// rotation + foreground notifications above — VLC's rendering layer
    /// can lose its drawable binding when the host bounds change (audio
    /// keeps playing, picture goes black). The backend's implementation
    /// nudges libvlc into rebinding to the current host.
    func refreshVideoOutput() {
        backend?.refreshDrawable()
    }
    #endif

    /// Pull `isPlaying` / `isBuffering` directly from the active backend.
    /// State callbacks normally keep these in sync, but events fired
    /// during a PiP enter/exit transition can land while the player view
    /// is between hosts and end up missed — call this after a PiP
    /// transition (or any other event that bypasses the state callback)
    /// so the in-app controls reflect what VLC is actually doing.
    public func syncPlaybackState() {
        guard let backend else { return }
        isPlaying = backend.isPlaying
        isBuffering = backend.isBuffering
    }

    public func playbackEndEvents() -> AsyncStream<Void> {
        backend?.playbackEndEvents() ?? AsyncStream { $0.finish() }
    }

    /// True when a PiP-end event should be allowed to drive a fresh
    /// detail-screen remount via `onPiPRestoreRequested`. Returns false
    /// during the cooldown window after a previous restore so a
    /// dismiss-initiated PiP that races into PiP-end can't loop the
    /// screen back open.
    public func shouldRestoreFromPiPEnd() -> Bool {
        guard let last = lastPiPRestoreAt else { return true }
        return Date().timeIntervalSince(last) > pipRestoreCooldown
    }

    /// Stamp the cooldown so subsequent PiP-end events suppress restore
    /// until enough time has passed. Call from the restore callsite right
    /// before invoking the registered handler.
    public func recordPiPRestoreFired() {
        lastPiPRestoreAt = Date()
    }

    // MARK: - Playback Control

    public func load(
        url: URL,
        startPosition: Double?,
        videoId: String? = nil,
        expectedSize: Int64? = nil
    ) {
        stop()

        // End the background transition task — new audio is about to start.
        #if !os(tvOS) && !os(watchOS)
        if playbackTransitionTask != .invalid {
            UIApplication.shared.endBackgroundTask(playbackTransitionTask)
            playbackTransitionTask = .invalid
        }
        #endif

        // tvOS doesn't use the prebuffer cache. The earlier behaviour
        // (clear cache + parallel download + swap-to-local) was making
        // playback appear to wait for the full download to complete on
        // some setups — VLC streams the URL directly here and the swap
        // path is iOS-only.
        #if os(tvOS)
        PlaybackCache.shared.clearAll()
        #endif

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        @Shared(.appStorage("vlcPrebufferToDisk")) var prebufferEnabled = PlaybackCache.defaultPrebufferEnabled
        @Shared(.appStorage("prebufferWifiOnly")) var prebufferWifiOnly = PlaybackCache.defaultPrebufferWifiOnly
        @Shared(.appStorage("playbackCacheSizeLimitBytes")) var cacheSizeLimitBytes = PlaybackCache.defaultCacheSizeLimitBytes

        // Cache-first: if we already have the file from a prior session,
        // play it directly as a file:// URL.
        var effectiveURL = url
        var playingFromCache = false
        if let videoId,
           !url.isFileURL,
           let cachedURL = PlaybackCache.shared.cachedFileURL(for: videoId) {
            effectiveURL = cachedURL
            playingFromCache = true
        }

        let newBackend: any PlayerBackend = PlaybackServiceBackend()
        setupBackendCallbacks(newBackend)
        // Assign `backend` BEFORE `load` so the seeded resume position
        // (and any state callbacks fired synchronously inside `load`)
        // actually flow through `setupBackendCallbacks`, which guards on
        // `self.backend` being non-nil.
        backend = newBackend
        currentVideoID = videoId
        isPlaying = true
        isBuffering = true
        // New playback always begins in the full detail container.
        activePlayerSurfaceRole = .fullDetail
        newBackend.load(
            url: effectiveURL,
            startPosition: startPosition
        )

        installPersistentSurface(for: newBackend)

        // Parallel download + swap: if the user opted in and we're not already
        // playing from cache or from an offline downloaded file, fetch the
        // full file to disk while playback streams. On completion the backend
        // swaps to the local file for instant-seek. Skipped on tvOS where
        // the swap-restart on completion was making playback appear to
        // wait for the cache to fill.
        let isOnWifi = Self.isConnectedToWifi()
        let shouldPrebuffer = prebufferEnabled && (!prebufferWifiOnly || isOnWifi)
        #if !os(tvOS)
        if !playingFromCache,
           shouldPrebuffer,
           !url.isFileURL,
           let videoId, !videoId.isEmpty {
            PlaybackCache.shared.startDownload(
                url: url,
                videoId: videoId,
                authHeaders: [:],
                expectedSize: expectedSize,
                limitBytes: cacheSizeLimitBytes
            ) { [weak self] fileURL in
                guard let self, self.currentVideoID == videoId else { return }
                if self.isInPiP {
                    // Mid-PiP swap would reset the player and visibly
                    // restart the video. Hold the URL and apply once PiP
                    // ends (or just use the file on the next play if the
                    // user fully dismisses PiP first).
                    self.pendingCacheSwapURL = fileURL
                } else {
                    self.backend?.swapToLocalFile(fileURL)
                }
                self.onCacheCompleted?(videoId)
            }
        }
        #endif
    }

    /// Called from the VLC player view's PiP teardown path. If a cache
    /// download finished while we were in PiP, apply the swap now.
    public func applyPendingCacheSwap() {
        guard let fileURL = pendingCacheSwapURL else { return }
        pendingCacheSwapURL = nil
        backend?.swapToLocalFile(fileURL)
    }

    public func stop() {
        #if !os(tvOS)
        if isInPiP {
            stopPiP()
        }
        #endif
        // Fire `onPause` before tearing state down so the reducer-installed
        // progress-save closure (which reads `currentTime` off this manager)
        // gets a final position to send to the server. Without this, stops
        // initiated from PiP teardown or external "stop" paths skip saving.
        onPause?()
        // Cancel any in-progress cache download so its completion callback
        // doesn't swap a stale file into the next video's backend.
        if let videoId = currentVideoID {
            PlaybackCache.shared.cancelDownload(videoId: videoId)
        }
        pendingCacheSwapURL = nil
        backend?.stop()
        backend = nil
        isPlaying = false
        isBuffering = true
        currentTime = 0
        duration = 0
        onPause = nil
        onPlaybackCompleted = nil
        isVLCFullscreen = false
        currentVideoID = nil
        currentMetadata = nil
        isInPiP = false
        activePiPDelegate = nil
        teardownPersistentSurface()
        #if !os(tvOS)
        nowPlayingService.teardown()
        #endif
    }

    public func pause() {
        backend?.pause()
        isPlaying = false
        onPause?()
        #if !os(tvOS)
        if currentMetadata != nil {
            nowPlayingService.updatePlaybackState(
                isPlaying: false,
                currentTime: currentTime,
                duration: duration
            )
        }
        #endif
    }

    public func resume() {
        backend?.play()
        isPlaying = true
        #if !os(tvOS)
        if currentMetadata != nil {
            nowPlayingService.updatePlaybackState(
                isPlaying: true,
                currentTime: currentTime,
                duration: duration
            )
        }
        #endif
    }

    public func seekTo(_ seconds: Double) {
        backend?.seekTo(seconds)
    }

    public func skipForward(_ seconds: Double = 10) {
        // Leave a 2s buffer at the end. Without this, rapid taps on the
        // skip-forward button accumulate past the end of the media —
        // libvlc reports the seek as a natural .stopped event, the
        // backend fires `onPlaybackEnd → onPlaybackCompleted`, and the
        // video gets marked watched + auto-advances. Letting playback
        // run into the end naturally still completes the video the
        // intended way.
        guard duration > 0 else { return }
        let safeEnd = max(currentTime, duration - 2)
        let target = min(currentTime + seconds, safeEnd)
        guard target > currentTime else { return }
        seekTo(target)
    }

    public func skipBackward(_ seconds: Double = 10) {
        let target = max(currentTime - seconds, 0)
        seekTo(target)
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    /// Apply a playback-rate multiplier to the active backend. Used by
    /// the tvOS fast-forward press-and-hold: rate 4.0 while held, back
    /// to 1.0 on release. Safe no-op when no backend is mounted.
    public func setPlaybackRate(_ rate: Float) {
        backend?.setPlaybackRate(rate)
    }

    public var currentTimeDisplay: String {
        Self.formatTime(currentTime)
    }

    public var durationDisplay: String {
        Self.formatTime(duration)
    }

    private static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "-" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }

    #if !os(tvOS) && !os(watchOS)
    public var vlcControlsVisible: Bool = true
    @ObservationIgnored private var vlcHideControlsTask: Task<Void, Never>?

    public func scheduleHideVLCControls() {
        vlcHideControlsTask?.cancel()
        vlcHideControlsTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.vlcControlsVisible = false
            }
        }
    }

    public func showVLCControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            vlcControlsVisible = true
        }
        scheduleHideVLCControls()
    }

    public func hideVLCControls() {
        vlcHideControlsTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            vlcControlsVisible = false
        }
    }

    public func cancelVLCHideControls() {
        vlcHideControlsTask?.cancel()
    }

    public func toggleVLCFullscreen() {
        isVLCFullscreen.toggle()
        if isVLCFullscreen {
            OrientationLock.shared.unlock()
        } else {
            OrientationLock.shared.lockPortrait()
        }
        scheduleHideVLCControls()
        // VLC's drawable doesn't auto-rebind when the host UIView
        // changes size via a SwiftUI layout animation — audio keeps
        // playing while the picture goes black. Wait for the layout
        // pass to settle, then force a drawable reattachment against
        // the current bounds (same pattern as the rotation handler).
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.refreshVideoOutput()
        }
    }
    #endif

    #if !os(tvOS)
    /// PiP entry points — wired to `PlaybackService.togglePictureInPicture`
    /// which uses VLCKit's iOS-only `VLCPictureInPictureDrawable`. The
    /// drawable is realized on the first play; if the host hasn't gotten
    /// that far yet `togglePictureInPicture` is a no-op and we report
    /// failure so the caller can fall back to the in-app mini player.
    public func startPiP() {
        guard backend is PlaybackServiceBackend else { return }
        PlaybackService.sharedInstance().togglePictureInPicture()
        isInPiP = PlaybackService.sharedInstance().isPipEnabled
    }

    @discardableResult
    public func startPiPIfAvailable() -> Bool {
        guard backend is PlaybackServiceBackend else { return false }
        let svc = PlaybackService.sharedInstance()
        svc.togglePictureInPicture()
        isInPiP = svc.isPipEnabled
        syncPlaybackState()
        return svc.isPipEnabled
    }

    public func stopPiP(keepPlayer: Bool = false) {
        guard isInPiP else { return }
        if backend is PlaybackServiceBackend {
            PlaybackService.sharedInstance().togglePictureInPicture()
        }
        isInPiP = false
        activePiPDelegate = nil
        syncPlaybackState()
    }
    #endif

    // MARK: - Persistent Player Surface

    private func installPersistentSurface(for backend: any PlayerBackend) {
        teardownPersistentSurface()
        _ = backend
    }

    private func teardownPersistentSurface() {
        #if canImport(VLCKit) && !os(watchOS)
        persistentVLCPlayerView?.removeFromSuperview()
        #endif
    }

    // MARK: - Network

    private nonisolated static func isConnectedToWifi() -> Bool {
        var flags: SCNetworkReachabilityFlags = []
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com"),
              SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }
        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)
        return isReachable && !isWWAN
    }

    // MARK: - Private

    private func setupBackendCallbacks(_ backend: any PlayerBackend) {
        backend.onTimeUpdate = { [weak self] time in
            guard let self, let backend = self.backend else { return }
            self.currentTime = time
            self.duration = backend.duration
            #if !os(tvOS)
            if self.currentMetadata != nil {
                self.nowPlayingService.updatePlaybackState(
                    isPlaying: self.isPlaying,
                    currentTime: time,
                    duration: self.duration
                )
            }
            #endif
        }

        backend.onStateChange = { [weak self] in
            guard let self, let backend = self.backend else { return }
            let wasPlaying = self.isPlaying
            self.isPlaying = backend.isPlaying
            self.isBuffering = backend.isBuffering
            self.duration = backend.duration
            if wasPlaying && !backend.isPlaying {
                self.onPause?()
            }
        }

        backend.onPiPStateChanged = { [weak self] enabled in
            guard let self else { return }
            self.isInPiP = enabled
            // PiP ended — apply any cache swap we deferred while in PiP.
            // Doing this mid-PiP would tear the rendering pipeline down
            // and visibly restart the video; now that PiP is off, the
            // swap-restart is just a normal source change.
            if !enabled {
                self.applyPendingCacheSwap()
            }
        }

        backend.onPlaybackEnd = { [weak self] in
            // Begin a background task immediately (on main thread) so iOS
            // doesn't suspend the app before the next video can start.
            #if !os(tvOS) && !os(watchOS)
            if self?.playbackTransitionTask != .invalid {
                if let task = self?.playbackTransitionTask {
                    UIApplication.shared.endBackgroundTask(task)
                }
            }
            self?.playbackTransitionTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.playbackTransitionTask = .invalid
            }
            #endif

            // Notify any registered observer (typically the VideoDetail
            // reducer's progress-save closure) that the video reached its
            // natural end. This fires regardless of whether the detail
            // screen is still presented — important for the PiP path,
            // where the detail screen has been dismissed but the player
            // continues running and the user expects the watched flag to
            // land on the server.
            self?.onPlaybackCompleted?()
        }
    }
}
#endif
