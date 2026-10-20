import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation
internal import SQLiteData
import StructuredQueries

public struct AutoPlayCountdown: Equatable, Sendable {
    public let nextVideo: VideoResponse
    /// Set to true if the resolved next video came from the play-next
    /// queue. Used to know whether the queue row should be popped (vs
    /// "up next" / similar, which aren't backed by the queue table).
    public let consumesPlayNextQueue: Bool
    public var remainingSeconds: Int

    public init(
        nextVideo: VideoResponse,
        consumesPlayNextQueue: Bool,
        remainingSeconds: Int
    ) {
        self.nextVideo = nextVideo
        self.consumesPlayNextQueue = consumesPlayNextQueue
        self.remainingSeconds = remainingSeconds
    }
}

@Reducer
public struct VideoDetailReducer {
    public init() {}
    /// Seconds the auto-advance overlay counts down before firing.
    public static let autoPlayCountdownSeconds = 5
    /// Seconds between periodic progress saves to the server while
    /// playback is active. Bridges the gap between pause/dismiss saves
    /// so a force-quit mid-play doesn't lose the run-up.
    public static let periodicProgressSaveInterval: Int = 15

    @ObservableState
    public struct State: Equatable, Sendable, Identifiable {
        public var id: String { video.videoId }
        var serverConfig: ServerConfig
        var video: VideoResponse
        var isPlaying: Bool = false
        var comments: [VideoComment] = []
        var isLoadingComments = false
        var similarVideos: [VideoResponse] = []
        var isLoadingSimilar = false
        var nextVideos: [VideoResponse] = []
        /// Ordered video IDs of the playlist this detail session was opened
        /// from, set only when the playlist's loop option is on. Once
        /// `nextVideos` runs dry, playback walks this list from the entry
        /// after the current video, wrapping past the end back to the top.
        var loopVideoIds: [String] = []
        /// Stack of videos we've auto-advanced past in this detail session —
        /// powers the "previous" transport button.
        var previousVideos: [VideoResponse] = []
        var shouldAutoPlayNextVideo: Bool = true
        var showPlayNext: Bool = true
        var isDownloaded = false
        var isDownloading = false
        var downloadProgress: Double = 0
        var downloadError: String?
        var isCached = false
        var isDeletingFromServer = false
        var isDescriptionExpanded = false
        /// tvOS: the comment open in the full-text view.
        var expandedComment: VideoComment?
        /// Set when the user answers the tvOS resume prompt with "start from
        /// beginning", and consumed by the next play so it seeks to 0 rather
        /// than the stored resume position.
        var playbackStartsAtBeginning = false
        var showAllComments = false
        /// iOS: comments whose replies are open. Threads start collapsed.
        var expandedThreadIDs: Set<String> = []
        var watchedOverride: Bool?
        var localWatchProgress: Double?
        var autoPlayCountdown: AutoPlayCountdown?
        /// True when this state is the one `TabReducer` holds for the mini
        /// player, rather than a screen pushed onto a tab's navigation
        /// stack. The mini player's copy is not presented by anyone, so it
        /// must not drive `@Dependency(\.dismiss)` — the tab tears it down
        /// in response to the delegate action instead.
        var isHostedInMiniPlayer = false
        /// True only while this state is being rendered *as* the small
        /// floating player. Distinct from `isHostedInMiniPlayer`, which
        /// stays true when the user taps the mini player back up to full
        /// screen — at which point the ordinary full-screen behaviours,
        /// auto-advance included, apply again.
        var isMiniPlayerCollapsed = false
        /// Set the first time the software-decode warning is shown. The
        /// limitation is a property of the device, not of any one video, so
        /// it's worth saying once and never again.
        @Shared(.hasSeenSoftwareDecodeWarning)
        var hasSeenSoftwareDecodeWarning
        @FetchAll(PlayNextItem.all.order(by: \.id))
        var playNextItems
        @Presents var playlistPicker: PlaylistPickerReducer.State?
        @Presents var alert: AlertState<AlertAction>?

        var youtubeURL: URL? { video.youtubeURL }
        /// Used for the TubeArchivist Share option. Points at the streaming
        /// media file rather than the `/video/{id}/` web UI page — the web
        /// UI requires a logged-in session, so a recipient opening the
        /// shared link in another app/browser would just hit the login wall.
        /// The media URL is served as a static file by the underlying
        /// webserver and doesn't require API auth.
        var tubeArchivistURL: URL? {
            guard let mediaPath = video.mediaUrl else { return nil }
            return serverConfig.fullURL(for: mediaPath)
        }
        var isWatched: Bool { watchedOverride ?? video.isWatched }
        var effectiveWatchProgress: Double { localWatchProgress ?? video.watchProgress }
        var channelThumbURL: URL? {
            guard let path = video.channel.channelThumbUrl else { return nil }
            return serverConfig.fullURL(for: path)
        }
        /// The hero thumbnail / child-mode poster.
        var thumbnailURL: URL? {
            serverConfig.thumbnailURL(videoId: video.videoId, path: video.vidThumbUrl)
        }
        /// The comments header's count: comments and their replies.
        var commentCount: Int {
            comments.totalCommentCount
        }

        /// Whether the current video is already queued in Play Next.
        var isInPlayNext: Bool {
            playNextItems.contains { $0.videoId == video.videoId }
        }
        /// What auto-advance will most likely play once this video ends,
        /// for the tvOS player's hint. Follows the order
        /// `handleVideoPlaybackDidEnd` resolves in, but only as far as is
        /// known ahead of time: a looping playlist and the server's similar
        /// lookup are only settled at the end, so they give no hint.
        var predictedNextItem: UpNextItem? {
            @Shared(.autoPlayEnabled) var autoPlayEnabled
            guard autoPlayEnabled else { return nil }
            if let queued = playNextItems.first {
                return upNextItem(for: queued)
            }
            if shouldAutoPlayNextVideo, let next = nextVideos.first {
                return upNextItem(for: next)
            }
            guard loopVideoIds.isEmpty else { return nil }
            return similarVideos.first.map { upNextItem(for: $0) }
        }

        var predictedNextTitle: String? {
            predictedNextItem?.title
        }

        /// The hint mirrored into the player: only while it's up.
        var upNextHint: UpNextItem? {
            isPlaying ? predictedNextItem : nil
        }

        var upNextHintTitle: String? {
            upNextHint?.title
        }

        private func upNextItem(for queued: PlayNextItem) -> UpNextItem {
            UpNextItem(
                id: queued.videoId,
                title: queued.title,
                channelName: queued.channelName,
                thumbnailURL: queued.thumbUrl.flatMap { serverConfig.fullURL(for: $0) },
                duration: queued.duration
            )
        }

        private func upNextItem(for candidate: VideoResponse) -> UpNextItem {
            UpNextItem(
                id: candidate.videoId,
                title: candidate.title,
                channelName: candidate.channelName,
                thumbnailURL: candidate.vidThumbUrl.flatMap { serverConfig.fullURL(for: $0) },
                duration: candidate.durationStr
            )
        }

        /// The tvOS player's Up Next ribbon: the Play Next queue, the rest
        /// of the list this video was opened from, then similar videos —
        /// whatever could sensibly come next, whether or not autoplay is
        /// on. Only while the player is up.
        var upNextRibbonItems: [UpNextItem] {
            guard isPlaying else { return [] }
            var seen: Set<String> = [video.videoId]
            var items: [UpNextItem] = []
            for queued in playNextItems where seen.insert(queued.videoId).inserted {
                items.append(upNextItem(for: queued))
            }
            for candidate in nextVideos + similarVideos
            where seen.insert(candidate.videoId).inserted {
                items.append(upNextItem(for: candidate))
            }
            return Array(items.prefix(Self.upNextRibbonLimit))
        }

        static let upNextRibbonLimit = 12

        /// The "up next" card, in the shape both the inline overlay and the
        /// fullscreen player (via `PlayerClient.setAutoPlayCountdown`) take.
        var autoPlayCountdownInfo: AutoPlayCountdownInfo? {
            guard let countdown = autoPlayCountdown else { return nil }
            return AutoPlayCountdownInfo(
                title: countdown.nextVideo.title,
                thumbnailURL: countdown.nextVideo.vidThumbUrl
                    .flatMap { serverConfig.fullURL(for: $0) },
                remainingSeconds: countdown.remainingSeconds,
                totalSeconds: VideoDetailReducer.autoPlayCountdownSeconds
            )
        }

        public init(
            serverConfig: ServerConfig,
            video: VideoResponse,
            nextVideos: [VideoResponse] = [],
            loopVideoIds: [String] = [],
            shouldAutoPlayNextVideo: Bool = true,
            showPlayNext: Bool = true,
            isPlaying: Bool = false
        ) {
            self.serverConfig = serverConfig
            self.video = video
            self.nextVideos = nextVideos
            self.loopVideoIds = loopVideoIds
            self.shouldAutoPlayNextVideo = shouldAutoPlayNextVideo
            self.showPlayNext = showPlayNext
            self.isPlaying = isPlaying
        }

        mutating func resetForNewVideo(_ video: VideoResponse) {
            self.video = video
            isPlaying = false
            comments = []
            isLoadingComments = false
            similarVideos = []
            isLoadingSimilar = false
            isDownloaded = false
            isDownloading = false
            downloadProgress = 0
            downloadError = nil
            isDeletingFromServer = false
            isDescriptionExpanded = false
            expandedComment = nil
            playbackStartsAtBeginning = false
            showAllComments = false
            expandedThreadIDs = []
            watchedOverride = nil
            localWatchProgress = nil
            playlistPicker = nil
            autoPlayCountdown = nil
        }
    }

    public enum AlertAction: Equatable, Sendable {
        case dismissed
        case confirmDeleteFromServer
        case confirmSoftwareDecodePlayback
        case retryPlayback
        case playFromBeginning
        case resumeFromPosition
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case delegate(Delegate)
        case binding(BindingAction<State>)

        case playlistPicker(PresentationAction<PlaylistPickerReducer.Action>)
        case alert(PresentationAction<AlertAction>)
        /// Results carry the video they were fetched for: an in-place
        /// switch (similar, next up, auto-advance) can leave a response for
        /// the previous video in flight, and it must not land on this one.
        case videoRefreshed(VideoResponse)
        case commentsResult(videoId: String, Result<[VideoComment], Error>)
        case similarResult(videoId: String, Result<[VideoResponse], Error>)
        case downloadResumed(videoId: String, progress: Double)
        case downloadProgressUpdated(videoId: String, progress: Double)
        case downloadCompleted(videoId: String)
        case downloadFailed(videoId: String, message: String)
        case downloadCancelled(videoId: String)
        case autoPlayVideo(VideoResponse)
        /// Nothing follows the finished video. Also a signal to `TabReducer`,
        /// which retires the mini player when its copy sends this — so it is
        /// sent as an action rather than run as a shared handler.
        case autoPlayExhausted
        case autoPlayCountdownStarted(VideoResponse, consumesPlayNextQueue: Bool)
        case playlistLoopAdvanced(VideoResponse, nextVideos: [VideoResponse])
        case autoPlayCountdownTick
        case cacheStatusChanged(Bool)
        /// Playback stopped without reaching the end — a failed load, or an
        /// engine error.
        case playbackFailed
        case pipRestoreRequested(VideoResponse)
        case adoptInflightPlayback
        /// Re-attach to playback that is already running for this video.
        /// Sent by `TabReducer` when a dragged-down detail screen becomes
        /// the mini player: the screen's playback effect died with its
        /// store, so auto-advance and progress saving need a new
        /// subscription to `PlayerManager.events`.
        case resumePlaybackObservation
        case serverDeleteResult(Result<Void, Error>)
        case watchedToggleResult(Result<Void, Error>)

        public enum Delegate {
            case didRequestMinimize
            case didDismiss(String)
        }

        @CasePathable
        public enum View {
            case viewDidAppear
            case playTapped
            case stopPlayback
            case dismissTapped
            case minimizeRequested
            /// The tvOS player cover was shown or dismissed.
            case playerPresentationChanged(Bool)
            case channelTapped
            case downloadTapped
            case deleteDownloadTapped
            case deleteFromServerTapped
            case similarVideoTapped(VideoResponse)
            case nextUpVideoTapped(VideoResponse)
            case videoPlaybackDidEnd
            case toggleDescription
            case commentsHeaderTapped
            case commentTapped(VideoComment)
            case repliesToggled(commentId: String)
            case upNextRibbonItemSelected(videoId: String)
            case toggleWatchedTapped
            case addToPlaylistTapped
            case addToPlayNextTapped
            case addUpNextToPlayNextTapped(VideoResponse)
            case removeFromPlayNextTapped(Int)
            case playNextItemTapped(PlayNextItem)
            case nextVideoRequested
            case previousVideoRequested
            case autoPlayCountdownPlayNowTapped
            case autoPlayCountdownCancelTapped
            /// Child mode's play/pause button.
            case childPlayPauseTapped
            /// Child mode's seek bar, as a fraction of the duration.
            case childSeekRequested(Double)
        }
    }

    enum CancelID {
        case playback
        case autoPlayCountdown
        /// Mirrors the countdown into the fullscreen player.
        case countdownMirror
        case upNextMirror
        case upNextRibbonMirror
        /// Resolving what plays next once a video ends.
        case autoPlayResolve
        /// Per-video loads. Each restarts with `cancelInFlight` whenever the
        /// screen switches video, so the previous video's work can't land.
        case refresh
        case comments
        case similar
        case downloadObservation
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.videoService) var videoService
    @Dependency(\.localVideoStorage) var localVideoStorage
    @Dependency(\.persistentDownloadManager) var persistentDownloadManager
    @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase
    @Dependency(\.playNextDatabase) var playNextDatabase
    @Dependency(\.miniPlayerClient) var miniPlayerClient
    @Dependency(\.playerClient) var playerClient
    @Dependency(\.offlineMedia) var offlineMedia
    @Dependency(\.date.now) var now

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .delegate:
                return .none
            case .playlistPicker:
                return .none
            case .alert(.presented(.confirmDeleteFromServer)):
                return handleConfirmedDeleteFromServer(state: &state)
            case .alert(.presented(.confirmSoftwareDecodePlayback)),
                 .alert(.presented(.retryPlayback)):
                return handlePlayTapped(state: &state)
            case .alert(.presented(.playFromBeginning)):
                state.playbackStartsAtBeginning = true
                return handlePlayTappedWarningIfNeeded(state: &state)
            case .alert(.presented(.resumeFromPosition)):
                state.playbackStartsAtBeginning = false
                return handlePlayTappedWarningIfNeeded(state: &state)
            case .alert:
                return .none
            default:
                return handleInternalAction(action, state: &state)
            }
        }
        .ifLet(\.$playlistPicker, action: \.playlistPicker) {
            PlaylistPickerReducer()
        }
        .ifLet(\.$alert, action: \.alert)
        .onChange(of: \.autoPlayCountdown) { _, _ in
            // Mirror the countdown into the fullscreen player, which has no
            // access to this store. One cancellable effect, so a late write
            // can never restore a card that has since been cleared. The
            // card's taps come back over the player event stream, owned by
            // the countdown effect in `handleAutoPlayCountdownStarted`.
            Reduce { state, _ in
                let info = state.autoPlayCountdownInfo
                return .run { [playerClient] _ in
                    await playerClient.setAutoPlayCountdown(info)
                }
                .cancellable(id: CancelID.countdownMirror, cancelInFlight: true)
            }
        }
        .onChange(of: \.upNextHint) { _, _ in
            // Only the tvOS player draws the hint. Keyed on `isPlaying` too,
            // so pressing Play publishes a guess that was settled before.
            Reduce { state, _ in
                #if os(tvOS)
                let hint = state.upNextHint
                return .run { [playerClient] _ in
                    await playerClient.setUpNextHint(hint)
                }
                .cancellable(id: CancelID.upNextMirror, cancelInFlight: true)
                #else
                return .none
                #endif
            }
        }
        .onChange(of: \.upNextRibbonItems) { _, _ in
            // Only the tvOS player draws the ribbon.
            Reduce { state, _ in
                #if os(tvOS)
                let items = state.upNextRibbonItems
                return .run { [playerClient] _ in
                    await playerClient.setUpNextItems(items)
                }
                .cancellable(id: CancelID.upNextRibbonMirror, cancelInFlight: true)
                #else
                return .none
                #endif
            }
        }
    }
}

#if os(tvOS)
// MARK: - tvOS display

extension VideoDetailReducer.State {
    /// "1.2K views · 3 days ago", the tvOS hero's first metadata line after
    /// the channel name.
    var viewsAndPublishedText: String? {
        let parts = [
            video.formattedViewCount.map { String.localised("video.viewCount \($0)", table: .videos) },
            video.publishedRelative
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The hero thumbnail, straight from the server's thumbnail path.
    var heroThumbnailURL: URL? {
        video.vidThumbUrl.flatMap { serverConfig.fullURL(for: $0) }
    }

    /// Whether the hero's second metadata line (quality pill, duration) has
    /// anything to show.
    var hasQualityOrDuration: Bool {
        video.qualityLabel != nil || video.durationStr != nil
    }

    /// The description as plain text, for the clamped preview in the hero.
    var descriptionPreview: String? {
        guard let text = video.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    /// The description cut into focusable blocks for the full-text view.
    var descriptionBlocks: [String] {
        descriptionPreview?.descriptionBlocks() ?? []
    }

    /// Placeholder cards for the comments row while it loads.
    var commentPlaceholders: [VideoComment] {
        (0..<3).map { index in
            VideoComment(
                commentId: "placeholder-\(index)",
                commentText: VideoComment.placeholder.commentText,
                commentTimestamp: nil,
                commentLikeCount: VideoComment.placeholder.commentLikeCount,
                commentIsFavorited: false,
                commentAuthor: VideoComment.placeholder.commentAuthor,
                commentAuthorId: nil
            )
        }
    }
}

extension VideoComment {
    /// The comment cut into focusable blocks for the tvOS full-text view.
    var fullTextBlocks: [String] { (commentText ?? "").descriptionBlocks() }
}
#endif
