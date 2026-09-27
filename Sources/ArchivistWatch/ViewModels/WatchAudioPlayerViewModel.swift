#if os(watchOS)
import AVFoundation
import ArchivistNetworking
import Foundation
import MediaPlayer

/// Registrations that have to be undone when a player goes away: the periodic
/// time observer, the end-of-item observers and the handlers this player put
/// on the *shared* remote command centre. `deinit` is nonisolated and so
/// cannot reach `@MainActor` state — these closures can be run from it, and
/// are released with the box if `teardown()` never ran.
private final class WatchPlayerTeardownHandles: @unchecked Sendable {
    private let lock = NSLock()
    private var releases: [() -> Void] = []

    func add(_ release: @escaping () -> Void) {
        lock.withLock { releases.append(release) }
    }

    func releaseAll() {
        let pending = lock.withLock {
            let pending = releases
            releases = []
            return pending
        }
        pending.forEach { $0() }
    }

    deinit {
        releaseAll()
    }
}

@MainActor
@Observable
public final class WatchAudioPlayerViewModel {
    private enum Source {
        case stream(video: VideoResponse?)
        case file(URL, startPosition: TimeInterval)
    }

    private enum SetupState {
        case idle
        case loading
        case ready
        case failed
    }

    public private(set) var title: String
    public private(set) var channelName: String
    public private(set) var thumbPath: String?
    public private(set) var isPlaying = false
    public private(set) var isLoading = true
    public private(set) var isDownloading = false
    public private(set) var isDownloaded = false
    public private(set) var progress: Double = 0
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var errorMessage: String?
    /// Drives the delete confirmation. Set through `deleteButtonTapped()`;
    /// the dialog's binding clears it when dismissed.
    public var isShowingDeleteConfirmation = false

    public let videoId: String
    public let serverConfig: ServerConfig
    public let isStreaming: Bool

    public var downloadProgress: Double {
        services.downloadManager.progress
    }

    public var downloadProgressText: String {
        downloadProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    public var elapsedFormatted: String {
        DurationText.clock(seconds: elapsed)
    }

    public var remainingFormatted: String {
        "-\(DurationText.clock(seconds: max(duration - elapsed, 0)))"
    }

    public var canDownload: Bool {
        isStreaming && !isDownloaded
    }

    public var canDelete: Bool {
        isDownloaded || !isStreaming
    }

    public var playPauseLabel: String {
        isPlaying
            ? String(localized: "player.pause", bundle: .module)
            : String(localized: "player.play", bundle: .module)
    }

    public var playPauseSystemImage: String {
        isPlaying ? "pause.fill" : "play.fill"
    }

    @ObservationIgnored private let source: Source
    @ObservationIgnored private let services: WatchPlaybackServices
    @ObservationIgnored private var setupState = SetupState.idle
    @ObservationIgnored private var isTornDown = false
    @ObservationIgnored private var hasRemoteCommands = false
    @ObservationIgnored private var mediaUrl: String?
    @ObservationIgnored private var avPlayer: AVPlayer?
    @ObservationIgnored private var localPlayer: AVAudioPlayer?
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    @ObservationIgnored private var lastPersistedPosition: TimeInterval = 0
    @ObservationIgnored private let teardownHandles = WatchPlayerTeardownHandles()

    // MARK: - Init

    /// A streaming player. `video` may be nil (a playlist entry); the full
    /// video is then fetched when the player first loads.
    public init(
        videoId: String,
        title: String,
        channelName: String,
        thumbPath: String?,
        video: VideoResponse?,
        serverConfig: ServerConfig,
        services: WatchPlaybackServices
    ) {
        self.videoId = videoId
        self.title = title
        self.channelName = channelName
        self.thumbPath = thumbPath
        self.mediaUrl = video?.mediaUrl
        self.serverConfig = serverConfig
        self.services = services
        self.isStreaming = true
        self.source = .stream(video: video)
    }

    /// A player for a downloaded file, resuming from its saved position.
    public init(
        record: WatchDownload,
        fileURL: URL,
        serverConfig: ServerConfig,
        services: WatchPlaybackServices
    ) {
        self.videoId = record.id
        self.title = record.title
        self.channelName = record.channelName
        self.thumbPath = record.thumbPath
        self.serverConfig = serverConfig
        self.services = services
        self.isStreaming = false
        self.source = .file(fileURL, startPosition: record.lastPlayedPosition)
    }

    // MARK: - Lifecycle

    /// Loads the media. Called from the view's `.task`; safe to call again —
    /// it only does work until setup has succeeded, and a load cancelled
    /// half way (the screen left early) is retried on the next appearance.
    public func task() async {
        guard setupState == .idle, !isTornDown else { return }
        setupState = .loading
        isLoading = true
        isDownloaded = services.catalog.contains(videoId: videoId)

        let succeeded: Bool
        switch source {
        case let .stream(video):
            succeeded = await setupStreaming(video: video)
        case let .file(url, startPosition):
            succeeded = setupLocalPlayer(fileURL: url, startPosition: startPosition)
        }

        if Task.isCancelled || isTornDown {
            setupState = isTornDown ? .failed : .idle
            return
        }
        setupState = succeeded ? .ready : .failed
        isLoading = false
    }

    /// Leaving the screen doesn't end the session — playback carries on and the
    /// Now Playing tab keeps showing it. A player that was never started has
    /// nothing keeping it alive, so it releases its registrations here.
    public func viewDidDisappear() async {
        await saveProgress()
        if !services.nowPlaying.isActive(self) {
            teardown()
        }
    }

    /// Releases everything that outlives this instance: the observers, the
    /// progress loop, the handlers on the shared remote command centre and the
    /// audio session. `deinit` cannot touch `@MainActor` state, so a session
    /// ends through here.
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        stopProgressUpdates()
        persistLocalPosition()
        avPlayer?.pause()
        localPlayer?.stop()
        let wasActive = services.nowPlaying.isActive(self)
        isPlaying = false
        teardownHandles.releaseAll()
        services.nowPlaying.clearIfMatching(self)
        if wasActive {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - Transport

    public func togglePlayPause() async {
        if isPlaying {
            pause()
        } else {
            await play()
        }
    }

    public func skipForward() {
        seek(by: 30)
    }

    public func skipBackward() {
        seek(by: -15)
    }

    // MARK: - Downloads

    public func downloadButtonTapped() async {
        guard canDownload, !isDownloading else { return }
        isDownloading = true
        errorMessage = nil
        defer { isDownloading = false }

        do {
            var resolvedMediaUrl = mediaUrl
            if resolvedMediaUrl == nil {
                resolvedMediaUrl = try await services.videoService.getVideo(
                    config: serverConfig,
                    id: videoId
                )
                .mediaUrl
            }
            let item = WatchDownloadItem(
                videoId: videoId,
                title: title,
                channelName: channelName,
                mediaUrl: resolvedMediaUrl,
                duration: duration > 0 ? Int(duration) : nil,
                durationStr: duration > 0 ? DurationText.clock(seconds: duration) : nil,
                thumbPath: thumbPath
            )
            try await services.downloadManager.downloadAudio(
                video: item,
                config: serverConfig
            )
            isDownloaded = true
        } catch WatchDownloadError.cancelled {
            return
        } catch {
            errorMessage = String(localized: "action.downloadFailed", bundle: .module)
        }
    }

    public func deleteButtonTapped() {
        isShowingDeleteConfirmation = true
    }

    /// Deletes the downloaded file. The session ends with it, since the
    /// file this player may have been reading is gone.
    public func deleteConfirmed() {
        isShowingDeleteConfirmation = false
        do {
            try services.downloadManager.deleteDownload(videoId: videoId)
            isDownloaded = false
            teardown()
        } catch {
            errorMessage = String(localized: "download.deleteFailed", bundle: .module)
        }
    }

    // MARK: - Playback

    private func play() async {
        guard !isTornDown, setupState == .ready else { return }
        guard await activateAudioSession() else { return }
        if isStreaming {
            avPlayer?.play()
        } else {
            localPlayer?.play()
            startProgressUpdates()
        }
        isPlaying = true
        errorMessage = nil
        services.nowPlaying.setPlayer(self)
        if !hasRemoteCommands {
            configureRemoteCommands()
        }
        configureNowPlaying()
    }

    private func pause() {
        if isStreaming {
            avPlayer?.pause()
        } else {
            localPlayer?.pause()
            stopProgressUpdates()
        }
        isPlaying = false
        updateNowPlayingPlaybackState()
        Task { await saveProgress() }
    }

    private func seek(by offset: TimeInterval) {
        if isStreaming {
            guard let avPlayer else { return }
            let target = min(max(CMTimeGetSeconds(avPlayer.currentTime()) + offset, 0), duration)
            avPlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        } else {
            guard let localPlayer else { return }
            localPlayer.currentTime = min(max(localPlayer.currentTime + offset, 0), localPlayer.duration)
            updateLocalProgress()
        }
    }

    /// Final state when the media runs out: the position is saved as the end
    /// (the server treats that as watched) and the local copy restarts next
    /// time instead of resuming into the last second.
    private func playbackEnded() {
        stopProgressUpdates()
        isPlaying = false
        elapsed = duration
        progress = duration > 0 ? 1 : 0
        updateNowPlayingPlaybackState()
        let finalPosition = duration
        Task { await saveServerProgress(position: finalPosition) }
        elapsed = 0
        persistLocalPosition()
    }

    private func playbackFailed() {
        stopProgressUpdates()
        isPlaying = false
        errorMessage = String(localized: "player.playbackFailed", bundle: .module)
        updateNowPlayingPlaybackState()
    }

    /// Saves the position to the server and, for a download, locally. Not
    /// tied to the screen: a pause or disappearance must still land.
    private func saveProgress() async {
        guard duration > 0 else { return }
        persistLocalPosition()
        await saveServerProgress(position: elapsed)
    }

    /// Best effort: a failed write is retried by the next pause or periodic
    /// save, and there is nothing useful to show the user about it.
    private func saveServerProgress(position: TimeInterval) async {
        try? await services.videoService.setProgress(
            config: serverConfig,
            videoId: videoId,
            position: Int(position)
        )
    }

    // MARK: - Setup

    private func setupStreaming(video: VideoResponse?) async -> Bool {
        do {
            let fullVideo: VideoResponse
            if let video, video.mediaUrl != nil {
                fullVideo = video
            } else {
                fullVideo = try await services.videoService.getVideo(
                    config: serverConfig,
                    id: videoId
                )
            }
            guard !Task.isCancelled, !isTornDown else { return false }
            mediaUrl = fullVideo.mediaUrl
            title = fullVideo.title
            channelName = fullVideo.channelName
            thumbPath = fullVideo.vidThumbUrl ?? thumbPath

            guard let mediaPath = fullVideo.mediaUrl,
                  let mediaURL = serverConfig.fullURL(for: mediaPath) else {
                errorMessage = String(localized: "player.playbackFailed", bundle: .module)
                return false
            }

            let headers = serverConfig.isServerURL(mediaURL) ? serverConfig.authHeaders : [:]
            let asset = AVURLAsset(
                url: mediaURL,
                options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
            )
            let loadedDuration = try await asset.load(.duration)
            guard !Task.isCancelled, !isTornDown else { return false }

            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            duration = CMTimeGetSeconds(loadedDuration)

            if let position = fullVideo.resumePositionSeconds {
                await player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
                guard !Task.isCancelled, !isTornDown else { return false }
                updateStreamingProgress(seconds: position)
            }

            observe(player: player, item: playerItem)
            avPlayer = player
            return true
        } catch {
            if !Task.isCancelled {
                errorMessage = String(localized: "player.playbackFailed", bundle: .module)
            }
            return false
        }
    }

    private func observe(
        player: AVPlayer,
        item: AVPlayerItem
    ) {
        // Delivered on the main queue, so the blocks can assume the main
        // actor rather than write to it from off it.
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.updateStreamingProgress(seconds: CMTimeGetSeconds(time))
            }
        }
        teardownHandles.add { player.removeTimeObserver(timeObserver) }

        let center = NotificationCenter.default
        let ended = center.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.playbackEnded()
            }
        }
        let failed = center.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.playbackFailed()
            }
        }
        teardownHandles.add {
            center.removeObserver(ended)
            center.removeObserver(failed)
        }
    }

    private func setupLocalPlayer(
        fileURL: URL,
        startPosition: TimeInterval
    ) -> Bool {
        do {
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.prepareToPlay()
            duration = player.duration
            if startPosition > 0, startPosition < player.duration {
                player.currentTime = startPosition
            }
            localPlayer = player
            lastPersistedPosition = player.currentTime
            updateLocalProgress()
            return true
        } catch {
            errorMessage = String(localized: "player.playbackFailed", bundle: .module)
            return false
        }
    }

    // MARK: - Progress

    private func startProgressUpdates() {
        stopProgressUpdates()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.updateLocalProgress()
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func updateLocalProgress() {
        guard let localPlayer, duration > 0 else { return }
        if isPlaying, !localPlayer.isPlaying {
            playbackEnded()
            return
        }
        elapsed = localPlayer.currentTime
        progress = elapsed / duration
        updateNowPlayingElapsed()
        persistLocalPositionIfDue()
    }

    private func updateStreamingProgress(seconds: TimeInterval) {
        guard seconds.isFinite else { return }
        elapsed = seconds
        if duration > 0 {
            progress = min(elapsed / duration, 1)
        }
        updateNowPlayingElapsed()
        persistLocalPositionIfDue()
    }

    /// The server position isn't readable offline, so a downloaded video keeps
    /// its own copy — without it every download restarted from the beginning.
    private func persistLocalPosition() {
        guard !isStreaming || isDownloaded else { return }
        lastPersistedPosition = elapsed
        services.catalog.updatePosition(
            videoId: videoId,
            position: elapsed
        )
    }

    private func persistLocalPositionIfDue() {
        guard abs(elapsed - lastPersistedPosition) >= 10 else { return }
        persistLocalPosition()
    }

    // MARK: - Audio Session & Now Playing

    /// watchOS routes long-form audio (to headphones, and in the background)
    /// only with the `.longFormAudio` policy and the asynchronous `activate`,
    /// which may show the route picker. Returns false if no route was chosen.
    private func activateAudioSession() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                policy: .longFormAudio
            )
            let activated = try await session.activate()
            if !activated {
                errorMessage = String(localized: "player.playbackFailed", bundle: .module)
            }
            return activated
        } catch {
            errorMessage = String(localized: "player.playbackFailed", bundle: .module)
            return false
        }
    }

    private func configureNowPlaying() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = channelName
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed() {
        guard services.nowPlaying.isActive(self) else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    }

    private func updateNowPlayingPlaybackState() {
        guard services.nowPlaying.isActive(self) else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }

    /// Taken over when this player first plays, not when it's built — a
    /// player that is only being looked at must not steal the controls.
    private func configureRemoteCommands() {
        hasRemoteCommands = true
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipBackwardCommand.preferredIntervals = [15]

        addRemoteTarget(to: center.playCommand) { await $0.play() }
        addRemoteTarget(to: center.pauseCommand) { $0.pause() }
        addRemoteTarget(to: center.togglePlayPauseCommand) { await $0.togglePlayPause() }
        addRemoteTarget(to: center.skipForwardCommand) { $0.skipForward() }
        addRemoteTarget(to: center.skipBackwardCommand) { $0.skipBackward() }
    }

    /// The command centre is shared, so drop whatever an earlier player left
    /// on it and remember our own registration for `teardown()`.
    private func addRemoteTarget(
        to command: MPRemoteCommand,
        handler: @escaping @MainActor (WatchAudioPlayerViewModel) async -> Void
    ) {
        command.removeTarget(nil)
        let token = command.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return .noSuchContent }
                // The system callback is synchronous; activating the audio
                // session is not, so the command is carried out right after.
                Task { await handler(self) }
                return .success
            }
        }
        teardownHandles.add { command.removeTarget(token) }
    }
}

extension WatchAudioPlayerViewModel: Hashable {
    nonisolated public static func == (
        lhs: WatchAudioPlayerViewModel,
        rhs: WatchAudioPlayerViewModel
    ) -> Bool {
        lhs === rhs
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
#endif
