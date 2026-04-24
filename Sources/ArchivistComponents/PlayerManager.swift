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
        public let authHeaders: [String: String]

        public init(
            title: String,
            artist: String,
            duration: Double,
            artworkURL: URL?,
            authHeaders: [String: String]
        ) {
            self.title = title
            self.artist = artist
            self.duration = duration
            self.artworkURL = artworkURL
            self.authHeaders = authHeaders
        }
    }

    public private(set) var backend: (any PlayerBackend)?

    /// Backward-compatible AVPlayer access for AVPlayerViewControllerWrapper
    public var player: AVPlayer? {
        (backend as? AVPlayerBackend)?.avPlayer
    }

    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0
    public var currentVideoID: String?
    public var isInPiP = false
    public var isVLCFullscreen = false
    public var activePiPDelegate: AnyObject?
    /// Called when VLC PiP is dismissed by the user — triggers restore flow
    public var onPiPRestore: (() -> Void)?

    public var supportsPiP: Bool {
        backend is AVPlayerBackend || backend is VLCPlayerBackend
    }

    public var isUsingFallbackPlayer: Bool {
        backend is VLCPlayerBackend
    }

    public var isUsingVLC: Bool {
        backend is VLCPlayerBackend
    }

    #if !os(tvOS)
    public weak var activePlayerViewController: AVPlayerViewController?
    @ObservationIgnored private let nowPlayingService = NowPlayingService()
    #endif

    #if canImport(VLCKit) && !os(tvOS) && !os(watchOS)
    /// Persistent VLC drawable view. Created in `load()` for the VLC backend
    /// and reused across containers. Reparenting it never causes a drawable
    /// swap, which is what was making VLC video disappear during transitions.
    public private(set) var persistentVLCDrawable: VLCPiPDrawableView?
    #endif

    /// Called when PiP starts (from any backend) so the host (TabReducer)
    /// can auto-minimize the currently presented video detail. Without this
    /// the original AVPlayerVC may be torn down by SwiftUI while PiP is
    /// active, and the player has nowhere to render on restore.
    public var onPiPStartRequested: (() -> Void)?

    /// Identifies which container is currently allowed to host the persistent
    /// player surface. Without this, two wrapper instances briefly co-exist
    /// during a mini ↔ full transition and they'd fight over reparenting the
    /// surface, leaving the wrong container with the player.
    public var activePlayerSurfaceRole: PlayerSurfaceRole = .fullDetail

    #if !os(tvOS)
    private var interruptionObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var resignActiveObserver: NSObjectProtocol?
    private var becomeActiveObserver: NSObjectProtocol?
    #endif

    #if !os(tvOS) && !os(watchOS)
    /// Background task that keeps the app alive between videos so the
    /// auto-play transition can complete (fetch next video + start playback).
    private var playbackTransitionTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    public var onPause: (() -> Void)?

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

        // Detach the player from its host view BEFORE iOS suspends rendering
        // (e.g. screen lock). Routing this through the scene-phase action in
        // TCA was too slow — AVPlayer had already been paused by the time the
        // reducer handler ran. willResignActive fires early enough that we
        // can nil out `activePlayerViewController.player` while playback is
        // still owned by us, so audio keeps flowing in the background.
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.prepareForBackground()
            }
        }

        becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restoreForForeground()
            }
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

        @Shared(.appStorage("useVLCPlayer")) var useVLC = false
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

        let newBackend: any PlayerBackend
        if useVLC {
            let vlcBackend = VLCPlayerBackend()
            vlcBackend.onPiPStopped = { [weak self] in
                self?.onPiPRestore?()
            }
            vlcBackend.onPiPStarted = { [weak self] in
                self?.onPiPStartRequested?()
            }
            newBackend = vlcBackend
        } else {
            let avBackend = AVPlayerBackend()
            #if !os(tvOS)
            avBackend.onPiPStopped = { [weak self] in
                self?.onPiPRestore?()
            }
            #endif
            newBackend = avBackend
        }
        setupBackendCallbacks(newBackend)
        newBackend.load(
            url: effectiveURL,
            startPosition: startPosition
        )
        backend = newBackend
        currentVideoID = videoId
        isPlaying = true
        isBuffering = true
        // New playback always begins in the full detail container.
        activePlayerSurfaceRole = .fullDetail

        #if !os(tvOS)
        installPersistentSurface(for: newBackend)
        #endif

        // Parallel download + swap: if the user opted in and we're not already
        // playing from cache or from an offline downloaded file, fetch the
        // full file to disk while playback streams. On completion the backend
        // swaps to the local file for instant-seek.
        let isOnWifi = Self.isConnectedToWifi()
        // Don't run the parallel download while VLC is streaming: both hit the
        // same media URL and VLC starves waiting for bandwidth, so playback
        // takes forever to start. VLC has its own internal buffering.
        let shouldPrebuffer = prebufferEnabled && !useVLC && (!prebufferWifiOnly || isOnWifi)
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
                self.backend?.swapToLocalFile(fileURL)
            }
        }
    }

    public func stop() {
        #if !os(tvOS)
        if isInPiP {
            stopPiP()
        }
        #endif
        // Cancel any in-progress cache download so its completion callback
        // doesn't swap a stale file into the next video's backend.
        if let videoId = currentVideoID {
            PlaybackCache.shared.cancelDownload(videoId: videoId)
        }
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
        #if !os(tvOS)
        teardownPersistentSurface()
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

    // MARK: - Background Lifecycle

    #if !os(tvOS) && !os(watchOS)
    /// Called when the app enters background. Detaches the player from its
    /// visible layer/drawable so iOS does not pause playback when the hosting
    /// view is removed from the window. Audio continues via AVAudioSession
    /// `.playback` + `UIBackgroundModes: audio`.
    public func prepareForBackground() {
        guard !isInPiP else { return }
        if let avBackend = backend as? AVPlayerBackend {
            _ = avBackend
            activePlayerViewController?.player = nil
        }
        #if canImport(VLCKit)
        if let vlcBackend = backend as? VLCPlayerBackend {
            vlcBackend.detachDrawableForBackground()
        }
        #endif
    }

    /// Called when the app returns to the foreground. Reattaches the player
    /// to the currently active visual surface.
    public func restoreForForeground() {
        try? AVAudioSession.sharedInstance().setActive(true)
        if let avBackend = backend as? AVPlayerBackend {
            activePlayerViewController?.player = avBackend.avPlayer
        }
        #if canImport(VLCKit)
        if let vlcBackend = backend as? VLCPlayerBackend {
            if let drawable = persistentVLCDrawable {
                vlcBackend.reattachDrawableAfterBackground(drawable)
            }
        }
        #endif
    }
    #endif

    #if !os(tvOS)
    public func startPiP() {
        if let vlcBackend = backend as? VLCPlayerBackend {
            vlcBackend.startPiP()
            isInPiP = true
        }
    }

    public func stopPiP(keepPlayer: Bool = false) {
        guard isInPiP else { return }
        if let vlcBackend = backend as? VLCPlayerBackend {
            vlcBackend.stopPiP()
        }
        if !keepPlayer {
            activePlayerViewController?.player = nil
        }
        isInPiP = false
        activePiPDelegate = nil
        if !keepPlayer {
            activePlayerViewController = nil
        }
    }
    #endif

    // MARK: - Persistent Player Surface

    #if !os(tvOS)
    private func installPersistentSurface(for backend: any PlayerBackend) {
        // Wipe any leftovers from a previous video.
        teardownPersistentSurface()

        #if canImport(VLCKit)
        if let vlcBackend = backend as? VLCPlayerBackend {
            let drawable = VLCPiPDrawableView()
            drawable.backgroundColor = .black
            drawable.translatesAutoresizingMaskIntoConstraints = false
            drawable.mediaPlayer = vlcBackend.mediaPlayer
            drawable.backend = vlcBackend
            vlcBackend.attachDrawable(drawable)
            persistentVLCDrawable = drawable
        }
        #endif
    }

    private func teardownPersistentSurface() {
        #if canImport(VLCKit)
        persistentVLCDrawable?.removeFromSuperview()
        persistentVLCDrawable = nil
        #endif
    }
    #endif

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

