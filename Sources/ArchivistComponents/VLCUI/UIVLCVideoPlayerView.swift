import Combine

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import VLCKit

public class UIVLCVideoPlayerView: _PlatformView {

    private lazy var videoContentView = makeVideoContentView()

    private var configuration: VLCVideoPlayer.Configuration
    private var proxy: VLCVideoPlayer.Proxy?
    private let onTicksUpdated: (Int, VLCVideoPlayer.PlaybackInformation) -> Void
    private let onStateUpdated: (VLCVideoPlayer.State, VLCVideoPlayer.PlaybackInformation) -> Void
    private let loggingInfo: (logger: VLCVideoPlayerLogger, level: VLCVideoPlayer.LoggingLevel)?
    /// Exposed so that callers (e.g. our PiP adapter, or the backend that
    /// owns this view as a persistent rendering surface) can reach the
    /// underlying `VLCMediaPlayer`. VLCUI keeps it private upstream.
    public private(set) var currentMediaPlayer: VLCMediaPlayer?

    // Note: necessary as the configuration values have to be set
    //       after streams have been added and playback starts for
    //       at least one tick-changed report. This could cause a
    //       small, noticeable jump when playback starts.
    private var hasSetConfiguration: Bool = false
    private var lastAspectFill: Float = 0
    private var lastPlayerTicks: Int32 = 0
    private var lastPlayerState: VLCMediaPlayerState = .opening

    private var aspectFillScale: CGFloat {
        guard let currentMediaPlayer else { return 1 }
        let videoSize = currentMediaPlayer.videoSize
        let fillSize = CGSize.aspectFill(aspectRatio: videoSize, minimumSize: videoContentView.bounds.size)
        return fillSize.scale(other: videoContentView.bounds.size)
    }

    init(
        configuration: VLCVideoPlayer.Configuration,
        proxy: VLCVideoPlayer.Proxy?,
        onTicksUpdated: @escaping (Int, VLCVideoPlayer.PlaybackInformation) -> Void,
        onStateUpdated: @escaping (VLCVideoPlayer.State, VLCVideoPlayer.PlaybackInformation) -> Void,
        loggingInfo: (VLCVideoPlayerLogger, VLCVideoPlayer.LoggingLevel)?
    ) {
        self.configuration = configuration
        self.proxy = proxy
        self.onTicksUpdated = onTicksUpdated
        self.onStateUpdated = onStateUpdated
        self.loggingInfo = loggingInfo
        super.init(frame: .zero)

        proxy?.videoPlayerView = self

        #if os(macOS)
        layer?.backgroundColor = .clear
        #else
        backgroundColor = .clear
        #endif

        setupVideoContentView()
        setupVLCMediaPlayer(with: configuration)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVideoContentView() {
        addSubview(videoContentView)

        NSLayoutConstraint.activate([
            videoContentView.topAnchor.constraint(equalTo: topAnchor),
            videoContentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoContentView.leftAnchor.constraint(equalTo: leftAnchor),
            videoContentView.rightAnchor.constraint(equalTo: rightAnchor),
        ])
    }

    /// True once a host has called `activatePlayback()` on us. Until then
    /// `setupVLCMediaPlayer` only stages the player without actually
    /// starting it — iOS's libvlc rendering / TLS path mis-handles
    /// `play()` issued before the drawable is in a real window.
    private var hasActivated = false
    private var pendingAutoPlay = false

    func setupVLCMediaPlayer(with newConfiguration: VLCVideoPlayer.Configuration) {
        currentMediaPlayer?.stop()
        currentMediaPlayer = nil

        guard let media = VLCMedia(url: newConfiguration.url) else { return }
        // libvlc media options are colon-prefixed strings (e.g.
        // `:network-caching=1500`). VLCMedia's `addOptions:` dictionary
        // form silently ignores entries that aren't already in this form,
        // so apply each as `addOption(":key=value")` (booleans collapse to
        // bare `:key`). This matches the pre-swap backend's invocation.
        for (key, value) in newConfiguration.options {
            if let bool = value as? Bool {
                if bool { media.addOption(":\(key)") }
            } else {
                media.addOption(":\(key)=\(value)")
            }
        }

        let newMediaPlayer = VLCMediaPlayer()
        newMediaPlayer.media = media
        // Defer `drawable` assignment until the host adds us to a window.
        // Attaching the drawable before there's a real window upstream
        // makes libvlc's iOS rendering path stall — the pre-swap flow
        // attached the drawable only after `play()` (via the host's
        // `attachDrawable`) and worked reliably.
        newMediaPlayer.delegate = self

        // VLCKit's `VLCLibrary.debugLogging*` setters and the
        // `VLCLibraryLogReceiverProtocol` consumer were removed in favour of
        // the newer `VLCLogging`/`VLCConsoleLogger` types. The VLCUI logging
        // hook was a developer convenience we don't drive from our app, so
        // this is a no-op on this VLCKit build.
        _ = loggingInfo

        for child in newConfiguration.playbackChildren {
            newMediaPlayer.addPlaybackSlave(child.url, type: child.type.asVLCSlaveType, enforce: child.enforce)
        }

        hasSetConfiguration = false
        configuration = newConfiguration
        currentMediaPlayer = newMediaPlayer
        proxy?.mediaPlayer = newMediaPlayer
        lastPlayerTicks = 0
        lastPlayerState = .opening

        if newConfiguration.autoPlay {
            if hasActivated {
                // We've already been attached to a window once — the
                // drawable assignment + `play()` need to happen now for
                // this fresh `VLCMediaPlayer`, otherwise the swap stages
                // a player that never gets a render target.
                newMediaPlayer.drawable = videoContentView
                newMediaPlayer.play()
            } else {
                pendingAutoPlay = true
            }
        }
    }

    func setAspectFill(with percentage: Float) {
        guard percentage >= 0, percentage <= 1 else { return }
        let scale = 1 + CGFloat(percentage) * (aspectFillScale - 1)
        videoContentView.scale(x: scale, y: scale)

        lastAspectFill = percentage
    }

    private func makeVideoContentView() -> _PlatformView {
        #if os(macOS)
        let view = _PlatformView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer?.backgroundColor = .black
        return view
        #else
        // On iOS / tvOS the VLCKit drawable doubles as the PiP source —
        // VLCKit calls `pictureInPictureReady()` on whichever view we hand
        // it as `mediaPlayer.drawable`, so this view (not the outer
        // UIVLCVideoPlayerView) must be the one that conforms to the PiP
        // protocols. `VLCVideoContentView` does that by forwarding back to
        // the host.
        let view = VLCVideoContentView(host: self)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        return view
        #endif
    }

    #if !os(macOS)
    override public func layoutSubviews() {
        super.layoutSubviews()

        setAspectFill(with: lastAspectFill)
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        activatePlayback()
    }

    /// Wires the staged `VLCMediaPlayer` to its drawable and starts
    /// playback. Idempotent.
    ///
    /// On the first call (after `setupVLCMediaPlayer` deferred autoplay
    /// because we weren't yet hosted), we assign the drawable and call
    /// `play()`.
    ///
    /// On subsequent calls (player view reparented between mini ↔ full),
    /// we nudge VLC with pause+play+seek so it re-evaluates its drawable
    /// against the new host's window-backed layer. Without this, second
    /// and subsequent reparenting keeps audio playing but renders black —
    /// VLC's video output stays bound to the previous window.
    func activatePlayback() {
        guard let player = currentMediaPlayer else {
            hasActivated = true
            return
        }

        if !hasActivated {
            hasActivated = true
            if player.drawable == nil {
                player.drawable = videoContentView
            }
            if pendingAutoPlay {
                pendingAutoPlay = false
                player.play()
            }
            return
        }

        // Reparent nudge — only meaningful while we're playing video.
        if player.isPlaying {
            let resume = player.time
            player.pause()
            player.play()
            player.time = resume
        }
    }
    #endif
}

// MARK: constructPlaybackInformation

extension UIVLCVideoPlayerView {

    private func constructPlaybackInformation(player: VLCMediaPlayer, media: VLCMedia) -> VLCVideoPlayer.PlaybackInformation {
        // The legacy track-collection helpers (`videoSubTitlesIndexes`,
        // `audioTrackIndexes`, etc.) and the matching scalar selectors
        // (`currentVideoSubTitleIndex`, `currentAudioTrackIndex`,
        // `currentVideoTrackIndex`) were removed from VLCKit in favour of
        // the new track-collection APIs. We don't expose a track switcher
        // in our UI, so feed the upstream PlaybackInformation struct empty
        // arrays and a "Disable" sentinel for the current selection.
        let disabled = MediaTrack(index: -1, title: "Disable")

        return VLCVideoPlayer.PlaybackInformation(
            startConfiguration: configuration,
            position: Float(player.position),
            length: media.length.intValue.asInt,
            isSeekable: player.isSeekable,
            playbackRate: Float(player.rate),
            videoSize: player.videoSize,
            currentSubtitleTrack: disabled,
            currentAudioTrack: disabled,
            currentVideoTrack: disabled,
            subtitleTracks: [],
            audioTracks: [],
            videoTracks: [],
            statistics: .init(stats: media.statistics)
        )
    }
}

// MARK: VLCMediaPlayerDelegate

extension UIVLCVideoPlayerView: @preconcurrency VLCMediaPlayerDelegate {

    // VLCKit invokes these from a worker thread. UIView is `@MainActor` in
    // Swift 6, so without `nonisolated` the delegate dispatch traps with
    // EXC_BREAKPOINT on every callback. Hop to MainActor to actually mutate
    // anything; the player + media are read locally on the call thread,
    // which is fine because the underlying VLC state is already locked by
    // the time it fires the notification.
    nonisolated public func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer,
              let media = player.media else { return }
        let currentTicks = player.time.intValue
        let mediaLength = media.length.intValue
        // VLCMediaPlayer / VLCMedia aren't `Sendable`; route through
        // unsafe-Sendable boxes so the MainActor hop compiles. The objects
        // are reference-counted and thread-safe in practice for the reads
        // we do on the other end.
        let playerBox = SendableBox(player)
        let mediaBox = SendableBox(media)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let player = playerBox.value
            let media = mediaBox.value
            let playbackInformation = self.constructPlaybackInformation(player: player, media: media)

            if !self.hasSetConfiguration {
                self.setConfigurationValues(with: player, from: self.configuration)
                self.hasSetConfiguration = true
            } else {
                self.onTicksUpdated(currentTicks.asInt, playbackInformation)
            }

            // Set playing state
            if self.lastPlayerState != .playing,
               abs(currentTicks - self.lastPlayerTicks) >= 200 {
                self.onStateUpdated(.playing, playbackInformation)
                self.lastPlayerState = .playing
                self.lastPlayerTicks = currentTicks
            }

            // Replay
            if self.configuration.replay,
               self.lastPlayerState == .playing,
               abs(mediaLength - currentTicks) <= 500 {
                self.configuration.autoPlay = true
                self.configuration.startTime = .ticks(0)
                self.setupVLCMediaPlayer(with: self.configuration)
            }
        }
    }

    nonisolated public func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        // Snapshot the bits we need on the call thread; `player.media` may
        // already be nil during the `.stopping`/`.stopped` transition.
        let state = player.state
        let media = player.media
        let playerBox = SendableBox(player)
        let mediaBox = media.map(SendableBox.init)
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard state != .playing, state != self.lastPlayerState else { return }

            let wrappedState = VLCVideoPlayer.State(rawValue: state.rawValue) ?? .error
            if let media = mediaBox?.value {
                let playbackInformation = self.constructPlaybackInformation(player: playerBox.value, media: media)
                self.onStateUpdated(wrappedState, playbackInformation)
            }
            self.lastPlayerState = state
        }
    }

    private func setConfigurationValues(with player: VLCMediaPlayer, from configuration: VLCVideoPlayer.Configuration) {
        // Note: upstream VLCUI sets `player.time = startTime` here. We
        // skip that; the host's backend drives resume seeks across
        // multiple delegate callbacks (.playing, length-changed,
        // time-changed) because a single seek-on-first-tick silently
        // fails on HTTP streams whose `isSeekable` lies briefly during
        // startup, and the failed attempt can leave the decoder wedged.
        let defaultPlayerSpeed = player.rate(from: configuration.rate)
        player.fastForward(atRate: defaultPlayerSpeed)

        if configuration.aspectFill {
            videoContentView.scale(x: aspectFillScale, y: aspectFillScale)
        } else {
            videoContentView.apply(transform: .identity)
        }

        // Track-index setters were removed from VLCKit (see the equivalent
        // note in `constructPlaybackInformation`). Resolve the configured
        // selectors anyway in case our stub helpers gain real behaviour
        // later, but don't try to push them at the player.
        _ = player.subtitleTrackIndex(from: configuration.subtitleIndex)
        _ = player.audioTrackIndex(from: configuration.audioIndex)

        player.setSubtitleSize(configuration.subtitleSize)
        player.setSubtitleFont(configuration.subtitleFont)
        player.setSubtitleColor(configuration.subtitleColor)
    }
}

// MARK: VLCLibraryLogReceiverProtocol — removed from VLCKit; see logging
// notes in `setupVLCMediaPlayer`.

/// Unsafe-`Sendable` wrapper used to ferry VLCKit reference types
/// (`VLCMediaPlayer`, `VLCMedia`) across actor hops in the delegate dispatch.
/// Those classes aren't annotated `Sendable` upstream but the property reads
/// we do on the other end are safe in practice — VLCKit serialises mutation
/// behind its own locks.
private struct SendableBox<T: AnyObject>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Picture in Picture
//
// Local addition (not in upstream VLCUI). VLCKit's PiP integration funnels
// through three Objective-C protocols and one entry point on `VLCMediaPlayer`:
//
//   - `VLCPictureInPictureDrawable` — the *drawable view* (whatever we set
//     as `mediaPlayer.drawable`) registers as the PiP source.
//     `pictureInPictureReady()` is called by VLCKit with the controller it
//     just minted; we hold it weakly so we can drive start/stop later.
//   - `VLCPictureInPictureMediaControlling` — VLCKit asks the drawable to
//     play / pause / seek / report time as the user interacts with the
//     system PiP overlay.
//   - `VLCPictureInPictureWindowControlling` — the controller VLCKit hands
//     us; what we call to start/stop PiP and to invalidate playback state.
//
// `UIVLCVideoPlayerView` itself is *not* the drawable — it has an inner
// `VLCVideoContentView` that VLC renders into. That inner view is what
// must conform to the protocols, otherwise `pictureInPictureReady()` is
// never called. The conformance forwards to the host's `currentMediaPlayer`.
//
// `pipController` is exposed off the host (the player view) so callers
// outside this file (the backend, `PlayerManager`) don't have to reach
// into VLCUI internals.

#if !os(macOS)
public final class VLCVideoContentView: UIView, VLCPictureInPictureDrawable, VLCPictureInPictureMediaControlling {
    // VLCKit invokes the PiP protocol methods from a non-main thread — make
    // every property/method involved `nonisolated(unsafe)` so Swift 6 strict
    // concurrency doesn't abort the process when those calls land. The
    // properties are touched only via the inherently-locked Obj-C calls
    // VLCKit makes, so the unsafe annotation is sound here.
    nonisolated(unsafe) weak var host: UIVLCVideoPlayerView?
    nonisolated(unsafe) weak var pipController: VLCPictureInPictureWindowControlling?

    init(host: UIVLCVideoPlayerView) {
        self.host = host
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    nonisolated public func mediaController() -> (any VLCPictureInPictureMediaControlling)? { self }

    nonisolated public func pictureInPictureReady() -> ((any VLCPictureInPictureWindowControlling)?) -> Void {
        { [weak self] controller in
            self?.pipController = controller
            // The in-app mini player was removed, so the source UI is
            // typically gone when PiP starts. When iOS hands PiP back we
            // need to clean up — but ONLY if the user actually dismissed
            // PiP (foreground state). The same `isStarted: false` event
            // also fires when the app is being backgrounded with PiP
            // already active, and we must NOT stop in that case or
            // background playback dies.
            controller?.stateChangeEventHandler = { isStarted in
                Task { @MainActor in
                    if isStarted {
                        PlayerManager.shared.isInPiP = true
                        return
                    }
                    PlayerManager.shared.isInPiP = false

                    // Always save progress when PiP ends — the
                    // reducer-installed `onPause` closure pulls
                    // `currentTime` off the player and posts it to the
                    // server. This fires regardless of which path we take
                    // below (continue inline / stop / leave running in
                    // background), so the user's position is always
                    // synced when PiP closes.
                    PlayerManager.shared.onPause?()

                    // If the player view is still hosted (its window is
                    // non-nil) the user pressed PiP-restore from inside
                    // the video detail screen — playback should continue
                    // there. Apply any pending cache swap that arrived
                    // while we were in PiP and let inline take over.
                    let stillHosted = PlayerManager.shared
                        .persistentVLCPlayerView?
                        .window != nil
                    if stillHosted {
                        PlayerManager.shared.applyPendingCacheSwap()
                        // Nudge the rendering pipeline so VLC re-binds the
                        // inline drawable layer (PiP moved the display
                        // layer to its own overlay; coming back, the
                        // inline view is otherwise often left black).
                        PlayerManager.shared.refreshVideoOutput()
                        return
                    }

                    // No host UI — the detail screen was dismissed before
                    // PiP started (the user closed the video while it was
                    // playing and PiP took over). When the app is active,
                    // PiP-end means the user tapped restore; ask the app
                    // to re-push the detail screen so playback has a
                    // surface. The new screen adopts the running player
                    // via `viewDidAppear`. If no callback is wired (e.g.
                    // tests, or app-launch race) fall back to stopping
                    // so we don't leak audio playback.
                    if UIApplication.shared.applicationState == .active {
                        if let videoId = PlayerManager.shared.currentVideoID,
                           let restore = PlayerManager.shared.onPiPRestoreRequested {
                            PlayerManager.shared.applyPendingCacheSwap()
                            restore(videoId)
                        } else {
                            PlayerManager.shared.stop()
                        }
                    } else {
                        PlayerManager.shared.applyPendingCacheSwap()
                    }
                }
            }
        }
    }

    nonisolated public func play() {
        host?.currentMediaPlayer?.play()
    }

    nonisolated public func pause() {
        host?.currentMediaPlayer?.pause()
    }

    nonisolated public func seek(by offset: Int64, completion: (() -> Void)!) {
        guard let player = host?.currentMediaPlayer else {
            completion?()
            return
        }
        if offset >= 0 {
            player.jumpForward(Double(offset))
        } else {
            player.jumpBackward(Double(-offset))
        }
        completion?()
    }

    nonisolated public func mediaLength() -> Int64 {
        Int64(host?.currentMediaPlayer?.media?.length.intValue ?? 0)
    }

    nonisolated public func mediaTime() -> Int64 {
        Int64(host?.currentMediaPlayer?.time.intValue ?? 0)
    }

    nonisolated public func isMediaSeekable() -> Bool {
        host?.currentMediaPlayer?.isSeekable == true
    }

    nonisolated public func isMediaPlaying() -> Bool {
        host?.currentMediaPlayer?.isPlaying == true
    }
}

extension UIVLCVideoPlayerView {
    /// The PiP controller VLCKit minted for our drawable, if any. Set by
    /// `VLCVideoContentView.pictureInPictureReady()`. Used by the backend
    /// to start/stop PiP.
    public var pipController: VLCPictureInPictureWindowControlling? {
        (videoContentView as? VLCVideoContentView)?.pipController
    }
}
#endif
