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

    public var supportsPiP: Bool {
        backend is VLCPlayerBackend
    }

    public var isUsingFallbackPlayer: Bool {
        backend is VLCPlayerBackend
    }

    public var isUsingVLC: Bool {
        backend is VLCPlayerBackend
    }

    #if !os(tvOS)
    @ObservationIgnored private let nowPlayingService = NowPlayingService()
    #endif

    #if canImport(VLCKit) && !os(watchOS)
    /// Persistent VLCUI player view. Created on first VLC `load()` and
    /// reused across containers. Reparenting the same `UIVLCVideoPlayerView`
    /// keeps the underlying `VLCMediaPlayer` alive, so transitions between
    /// the mini-player and the full video detail don't restart playback.
    public var persistentVLCPlayerView: UIVLCVideoPlayerView? {
        (backend as? VLCPlayerBackend)?.playerView
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
    #endif

    #if !os(tvOS) && !os(watchOS)
    /// Background task that keeps the app alive between videos so the
    /// auto-play transition can complete (fetch next video + start playback).
    private var playbackTransitionTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    public var onPause: (() -> Void)?
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
        ) { _ in
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
    #endif

    public func playbackEndEvents() -> AsyncStream<Void> {
        backend?.playbackEndEvents() ?? AsyncStream { $0.finish() }
    }

    // MARK: - Playback Control

    public func load(
        url: URL,
        startPosition: Double?,
        videoId: String? = nil
    ) {
        stop()

        // End the background transition task — new audio is about to start.
        #if !os(tvOS) && !os(watchOS)
        if playbackTransitionTask != .invalid {
            UIApplication.shared.endBackgroundTask(playbackTransitionTask)
            playbackTransitionTask = .invalid
        }
        #endif

        // tvOS wipes the cache at the start of every new playback so the box
        // isn't accumulating older videos on limited storage — each load gets
        // a fresh cache populated by the prebuffer download below.
        #if os(tvOS)
        PlaybackCache.shared.clearAll()
        #endif

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        @Shared(.appStorage("vlcPrebufferToDisk")) var prebufferEnabled = PlaybackCache.defaultPrebufferEnabled
        @Shared(.appStorage("prebufferWifiOnly")) var prebufferWifiOnly = PlaybackCache.defaultPrebufferWifiOnly

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

        let vlcBackend = VLCPlayerBackend()
        let newBackend: any PlayerBackend = vlcBackend
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
        // swaps to the local file for instant-seek.
        let isOnWifi = Self.isConnectedToWifi()
        let shouldPrebuffer = prebufferEnabled && (!prebufferWifiOnly || isOnWifi)
        if !playingFromCache,
           shouldPrebuffer,
           !url.isFileURL,
           let videoId, !videoId.isEmpty {
            PlaybackCache.shared.startDownload(
                url: url,
                videoId: videoId,
                authHeaders: [:]
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
        let target = min(currentTime + seconds, duration)
        seekTo(target)
    }

    public func skipBackward(_ seconds: Double = 10) {
        let target = max(currentTime - seconds, 0)
        seekTo(target)
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
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
    }
    #endif

    #if !os(tvOS)
    public func startPiP() {
        if let vlcBackend = backend as? VLCPlayerBackend {
            vlcBackend.startPiP()
            isInPiP = true
        }
    }

    /// Attempts to enter system PiP. Returns `true` if the platform actually
    /// minted a PiP controller and we kicked it off — `false` if PiP isn't
    /// available (Simulator, unsupported device, controller not yet ready),
    /// in which case the caller should fall back to the in-app mini player.
    @discardableResult
    public func startPiPIfAvailable() -> Bool {
        guard let vlcBackend = backend as? VLCPlayerBackend,
              let controller = vlcBackend.playerView?.pipController else {
            return false
        }
        controller.startPictureInPicture()
        isInPiP = true
        return true
    }

    public func stopPiP(keepPlayer: Bool = false) {
        guard isInPiP else { return }
        if let vlcBackend = backend as? VLCPlayerBackend {
            vlcBackend.stopPiP()
        }
        isInPiP = false
        activePiPDelegate = nil
    }
    #endif

    // MARK: - Persistent Player Surface

    private func installPersistentSurface(for backend: any PlayerBackend) {
        // Wipe any leftovers from a previous video.
        teardownPersistentSurface()
        // VLCUI's `UIVLCVideoPlayerView` is now the persistent surface and
        // is owned by `VLCPlayerBackend`. There's nothing extra to install
        // here — the host views read it back via `persistentVLCPlayerView`.
        _ = backend
    }

    private func teardownPersistentSurface() {
        // The backend owns the `UIVLCVideoPlayerView` lifecycle; it's torn
        // down inside `VLCPlayerBackend.stop()` (called from
        // `PlayerManager.stop()`). Detach from any current host so SwiftUI
        // hosts don't keep a dangling subview around.
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

        backend.onPlaybackEnd = { [weak self] in
            // Begin a background task immediately (on main thread) so iOS
            // doesn't suspend the app before the next video can start.
            #if !os(tvOS) && !os(watchOS)
            guard let self else { return }
            if self.playbackTransitionTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.playbackTransitionTask)
            }
            self.playbackTransitionTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.playbackTransitionTask = .invalid
            }
            #endif
        }
    }
}
#endif
