import ArchivistNetworking
import AVFoundation
import AVKit
import Network
#if !os(tvOS) && !os(watchOS)
import UIKit
#endif
#if canImport(Sharing)
import Sharing
#endif

#if !os(watchOS)
@Observable
@MainActor
public final class PlayerManager {
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
    public var activePiPDelegate: AnyObject?

    public var supportsPiP: Bool {
        backend is AVPlayerBackend
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

    #if !os(tvOS)
    private var interruptionObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    #endif

    public var onPause: (() -> Void)?

    private struct AuthContext {
        let videoId: String
        let videoService: any VideoServiceType
        let config: ServerConfig
    }

    private var pendingAuthContext: AuthContext?

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

    private init() {
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

    /// Stores auth context for VLC signed URLs. Must be called before
    /// `load()` when using the VLC backend. No-op for AVPlayer backend.
    public func configureAuth(
        videoId: String,
        videoService: any VideoServiceType,
        config: ServerConfig
    ) {
        pendingAuthContext = AuthContext(
            videoId: videoId,
            videoService: videoService,
            config: config
        )
    }

    public func load(
        url: URL,
        startPosition: Double?,
        authHeaders: [String: String] = [:],
        videoId: String? = nil
    ) {
        stop()

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        @Shared(.appStorage("useVLCPlayer")) var useVLC = false
        @Shared(.appStorage("vlcPrebufferToDisk")) var prebufferEnabled = false
        @Shared(.appStorage("prebufferWifiOnly")) var prebufferWifiOnly = true

        // Cache-first: if we already have the file from a prior session,
        // play it directly as a file:// URL. Skips signed URL flow entirely.
        var effectiveURL = url
        var effectiveAuthHeaders = authHeaders
        var playingFromCache = false
        if let videoId,
           !url.isFileURL,
           let cachedURL = PlaybackCache.shared.cachedFileURL(for: videoId) {
            effectiveURL = cachedURL
            effectiveAuthHeaders = [:]
            playingFromCache = true
        }

        let newBackend: any PlayerBackend
        if useVLC {
            let vlcBackend = VLCPlayerBackend()
            if !playingFromCache, let ctx = pendingAuthContext {
                vlcBackend.configureAuth(
                    videoId: ctx.videoId,
                    videoService: ctx.videoService,
                    config: ctx.config
                )
            }
            newBackend = vlcBackend
        } else {
            newBackend = AVPlayerBackend()
        }
        pendingAuthContext = nil
        setupBackendCallbacks(newBackend)
        newBackend.load(
            url: effectiveURL,
            startPosition: startPosition,
            authHeaders: effectiveAuthHeaders
        )
        backend = newBackend
        isPlaying = true
        isBuffering = true

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
                authHeaders: authHeaders
            ) { [weak self] fileURL in
                self?.backend?.swapToLocalFile(fileURL)
            }
        }
    }

    public func stop() {
        #if !os(tvOS)
        if isInPiP {
            stopPiP()
        }
        #endif
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

    #if !os(tvOS)
    public func stopPiP(keepPlayer: Bool = false) {
        guard isInPiP else { return }
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

    // MARK: - Network

    private static func isConnectedToWifi() -> Bool {
        let monitor = NWPathMonitor()
        let path = monitor.currentPath
        monitor.cancel()
        return path.usesInterfaceType(.wifi)
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
            // Handled via playbackEndEvents() async stream
        }
    }
}
#endif
