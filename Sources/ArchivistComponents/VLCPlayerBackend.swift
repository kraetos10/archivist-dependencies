#if !os(watchOS)
import ArchivistNetworking
import Foundation
import UIKit
import VLCKit

@MainActor
public final class VLCPlayerBackend: NSObject, PlayerBackend, @unchecked Sendable {
    public var mediaPlayer: VLCMediaPlayer

    public private(set) var isPlaying = false
    public private(set) var isBuffering = true
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0

    public var onTimeUpdate: ((Double) -> Void)?
    public var onStateChange: (() -> Void)?
    public var onPlaybackEnd: (() -> Void)?

    private var playbackEndContinuation: AsyncStream<Void>.Continuation?
    private var pendingStartPosition: Double?
    /// When a start-position seek is in flight, suppress time updates until
    /// VLC reports a time within 2s of this target (avoids a visible bounce
    /// back to 0 from stale notifications queued before the seek).
    private var seekTargetTime: Double?
    private var loadedMedia: VLCMedia?
    private var drawableView: UIView?

    // Signed URL auth
    private var baseURL: URL?
    private var videoId: String?
    private var videoService: (any VideoServiceType)?
    private var serverConfig: ServerConfig?
    private var currentSig: String?
    private var renewalTask: Task<Void, Never>?

    override public init() {
        mediaPlayer = VLCMediaPlayer()
        super.init()
        mediaPlayer.delegate = self
    }

    /// Configure auth for the next `load()` call. Must be called before `load()`.
    public func configureAuth(
        videoId: String,
        videoService: any VideoServiceType,
        config: ServerConfig
    ) {
        self.videoId = videoId
        self.videoService = videoService
        self.serverConfig = config
    }

    public func load(
        url: URL,
        startPosition: Double?,
        authHeaders: [String: String]
    ) {
        pendingStartPosition = startPosition
        isBuffering = true
        // Seed the UI with the resume position so the seek bar renders at the
        // correct spot from the first frame instead of flashing 0:00.
        if let startPosition, startPosition > 0 {
            currentTime = startPosition
            onTimeUpdate?(currentTime)
        }

        // Local files (including prebuffer cache hits) play directly — no
        // signed URL, no token, no renewal.
        if url.isFileURL {
            startPlaybackWithSignedURL(url)
            return
        }

        baseURL = url

        guard videoId != nil, videoService != nil, serverConfig != nil else {
            print("[VLC] Missing auth config — call configureAuth() first")
            isBuffering = false
            return
        }

        Task { [weak self] in
            await self?.fetchTokenAndStart()
        }
    }

    public func attachDrawable(_ view: UIView) {
        let wasPlaying = mediaPlayer.isPlaying
        let currentTime = mediaPlayer.time
        drawableView = view
        mediaPlayer.drawable = view

        if let media = loadedMedia, !mediaPlayer.isPlaying {
            mediaPlayer.media = media
            mediaPlayer.play()
            isPlaying = true
        } else if wasPlaying {
            // VLC needs a kick to start rendering onto the new drawable.
            // Stop + reload media + seek + play forces a fresh output pipeline.
            if let media = loadedMedia {
                mediaPlayer.stop()
                mediaPlayer.media = media
                mediaPlayer.play()
                mediaPlayer.time = currentTime
                isPlaying = true
            }
        }
    }

    public func play() {
        mediaPlayer.play()
        isPlaying = true
    }

    public func pause() {
        mediaPlayer.pause()
        isPlaying = false
        isBuffering = false
        onStateChange?()
    }

    public func stop() {
        // Revoke the current token on the server
        if let sig = currentSig,
           let service = videoService,
           let config = serverConfig,
           let id = videoId {
            Task {
                try? await service.revokeStreamToken(config: config, videoId: id, sig: sig)
            }
        }

        renewalTask?.cancel()
        renewalTask = nil

        mediaPlayer.stop()
        mediaPlayer.drawable = nil
        mediaPlayer.media = nil
        loadedMedia = nil
        drawableView = nil

        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        pendingStartPosition = nil
        seekTargetTime = nil
        baseURL = nil
        videoId = nil
        videoService = nil
        serverConfig = nil
        currentSig = nil

        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
    }

    public func seekTo(_ seconds: Double) {
        guard seconds >= 0 else { return }
        seekTargetTime = nil
        let milliseconds = Int32(seconds * 1000)
        mediaPlayer.time = VLCTime(int: milliseconds)
    }

    public func playbackEndEvents() -> AsyncStream<Void> {
        playbackEndContinuation?.finish()
        playbackEndContinuation = nil
        return AsyncStream { continuation in
            self.playbackEndContinuation = continuation
        }
    }

    // MARK: - Signed URL Handling

    private func fetchTokenAndStart() async {
        guard let baseURL,
              let videoId,
              let service = videoService,
              let config = serverConfig else {
            return
        }

        do {
            let response = try await service.getStreamToken(config: config, videoId: videoId)
            currentSig = response.sig

            guard let signedURL = buildSignedURL(base: baseURL, response: response) else {
                isBuffering = false
                onStateChange?()
                return
            }

            startPlaybackWithSignedURL(signedURL)
            scheduleRenewal(expiresAt: response.expires)
        } catch {
            // Server may not support signed URLs (older version or static
            // auth disabled) — fall back to the raw media URL.
            startPlaybackWithSignedURL(baseURL)
        }
    }

    private func buildSignedURL(base: URL, response: StreamTokenResponse) -> URL? {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        // Signed URLs go through the /stream/ nginx location which uses the
        // stream-auth subrequest instead of session auth.
        if let path = components?.path, path.hasPrefix("/youtube/") {
            components?.path = "/stream/" + path.dropFirst("/youtube/".count)
        }
        // Only `sig` lives in the URL. The server reads the expiry from Redis
        // alongside the stored HMAC payload, so we don't need to echo it back.
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "sig", value: response.sig))
        components?.queryItems = queryItems
        return components?.url
    }

    private func startPlaybackWithSignedURL(_ url: URL) {
        guard let media = VLCMedia(url: url) else {
            isBuffering = false
            return
        }

        Self.applyStreamingOptions(to: media)
        loadedMedia = media

        if let view = drawableView {
            mediaPlayer.drawable = view
        }
        mediaPlayer.media = media
        mediaPlayer.play()
        isPlaying = true
    }

    /// Swap to a local `file://` URL at the current playback position. Mirrors
    /// the token-renewal swap pattern. After this, VLC reads from disk so
    /// seeks are instant and we no longer need signed URLs or renewal.
    public func swapToLocalFile(_ fileURL: URL) {
        guard fileURL.isFileURL,
              let newMedia = VLCMedia(url: fileURL) else { return }
        Self.applyStreamingOptions(to: newMedia)

        let resumeTime = currentTime
        loadedMedia = newMedia
        mediaPlayer.media = newMedia
        mediaPlayer.play()

        if resumeTime > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self.seekTo(resumeTime)
            }
        }

        // Reading from disk now — cancel renewal and revoke the live token.
        renewalTask?.cancel()
        renewalTask = nil
        if let sig = currentSig,
           let service = videoService,
           let config = serverConfig,
           let id = videoId {
            currentSig = nil
            Task {
                try? await service.revokeStreamToken(config: config, videoId: id, sig: sig)
            }
        }
    }

    /// Applies the VLC media options we want on every streaming/local playback.
    /// - `:network-caching=60000` — 60s forward buffer so in-buffer seeks are instant.
    /// - `:http-reconnect` — resilience while filling the longer forward buffer.
    /// - `:prefetch-seek-threshold=1024` + `:input-fast-seek` — make Range seeks snappy.
    /// Harmless for `file://` URLs (network options are simply ignored).
    private static func applyStreamingOptions(to media: VLCMedia) {
        media.addOption(":network-caching=60000")
        media.addOption(":http-reconnect")
        media.addOption(":prefetch-seek-threshold=1024")
        media.addOption(":input-fast-seek")
    }

    private func scheduleRenewal(expiresAt: Int) {
        renewalTask?.cancel()
        // Renew 10 minutes before expiry, or 10 seconds from now if that's sooner
        let renewAt = max(expiresAt - 600, Int(Date().timeIntervalSince1970) + 10)
        let delay = renewAt - Int(Date().timeIntervalSince1970)
        guard delay > 0 else { return }

        renewalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.renewToken()
        }
    }

    private func renewToken() async {
        guard let baseURL,
              let videoId,
              let service = videoService,
              let config = serverConfig else {
            return
        }

        let oldSig = currentSig

        do {
            let response = try await service.getStreamToken(config: config, videoId: videoId)
            currentSig = response.sig

            // Reload VLC with the new URL at current playback time
            guard let newURL = buildSignedURL(base: baseURL, response: response),
                  let newMedia = VLCMedia(url: newURL) else { return }

            Self.applyStreamingOptions(to: newMedia)

            let resumeTime = currentTime
            loadedMedia = newMedia
            mediaPlayer.media = newMedia
            mediaPlayer.play()

            // Seek back to where we were after a short delay
            if resumeTime > 0 {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    self.seekTo(resumeTime)
                }
            }

            // Revoke the old token
            if let oldSig {
                Task {
                    try? await service.revokeStreamToken(config: config, videoId: videoId, sig: oldSig)
                }
            }

            scheduleRenewal(expiresAt: response.expires)
        } catch {
            print("[VLC] Renewal failed: \(error)")
        }
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlayerBackend: VLCMediaPlayerDelegate {
    nonisolated public func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            self.handleStateChange()
        }
    }

    nonisolated public func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            self.handleTimeChange()
        }
    }

    private func handleStateChange() {
        let state = mediaPlayer.state

        switch state {
        case .playing:
            isPlaying = true
            isBuffering = false
            applyPendingStartPositionIfReady()
        case .paused:
            isPlaying = false
            isBuffering = false
        case .buffering:
            if isPlaying || currentTime == 0 {
                isBuffering = true
            }
        case .stopped:
            isPlaying = false
            isBuffering = false
            if currentTime > 0, duration > 0, currentTime >= duration - 1 {
                playbackEndContinuation?.yield()
                onPlaybackEnd?()
            }
        case .error:
            isPlaying = false
            isBuffering = false
        default:
            break
        }
        onStateChange?()
    }

    private func handleTimeChange() {
        let timeMs = mediaPlayer.time.intValue
        let reportedTime = Double(timeMs) / 1000.0

        if let media = mediaPlayer.media {
            let lengthMs = media.length.intValue
            if lengthMs > 0 {
                duration = Double(lengthMs) / 1000.0
            }
        }

        // If we're still waiting to apply a start position, swallow updates
        // entirely — otherwise the UI flashes 0:00 before jumping to the
        // saved resume point.
        if pendingStartPosition != nil {
            applyPendingStartPositionIfReady()
            return
        }

        // If a start-position seek is in flight, swallow time updates until
        // VLC actually lands near the target.
        if let target = seekTargetTime {
            if abs(reportedTime - target) < 2.0 {
                seekTargetTime = nil
                currentTime = reportedTime
                onTimeUpdate?(currentTime)
            }
            return
        }

        currentTime = reportedTime
        onTimeUpdate?(currentTime)
    }

    private func applyPendingStartPositionIfReady() {
        guard let startPosition = pendingStartPosition,
              startPosition > 0,
              duration > 0 else { return }
        pendingStartPosition = nil
        let pos = startPosition / duration
        mediaPlayer.position = min(max(pos, 0), 1)
        // Show the target immediately; ignore stale time updates until VLC
        // confirms the seek landed.
        seekTargetTime = startPosition
        currentTime = startPosition
        onTimeUpdate?(currentTime)
    }
}
#endif
