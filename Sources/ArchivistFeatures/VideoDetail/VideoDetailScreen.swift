#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct VideoDetailScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        TVVideoDetailScreen(store: store)
    }
}
#else
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoDetailReducer.self)
public struct VideoDetailScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(ChildMode.enabledKey) private var childModeEnabled = false
    /// How far down the drag-to-minimise gesture has travelled. Drives the
    /// preview, and is reset (or handed to the reducer) on release.
    @State private var minimizeDrag: CGFloat = 0
    /// Whether the in-flight drag is a minimise. `nil` until the direction
    /// settles; `false` means this drag belongs to something else and is
    /// ignored for the rest of its life. Decided once per gesture — see
    /// `minimizeGesture`.
    @State private var isMinimizeDrag: Bool?

    /// Downward distance past which releasing commits to the mini player.
    private static let minimizeCommitDistance: CGFloat = 100
    /// Predicted travel that counts as a downward flick.
    private static let minimizeFlickDistance: CGFloat = 240
    /// Distance over which the screen's own background fades away as it is
    /// dragged down, so it reads as lifting off the app behind it. Set
    /// slightly beyond `minimizeCommitDistance` so a fully transparent
    /// background also tells the user that releasing will now minimise.
    private static let minimizeFadeDistance: CGFloat = 150

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    var isCompact: Bool {
        sizeClass == .compact
    }

    /// Opacity of the screen's own background during the minimise drag:
    /// solid at rest, fully clear once the drag is past the commit point.
    ///
    /// Only the background layer fades — the content on top of it stays
    /// opaque. Fading the whole subtree would composite the live video
    /// layer offscreen every frame, which is what made an earlier version
    /// of this drag stutter.
    private var minimizeBackgroundOpacity: Double {
        Double(1 - min(max(minimizeDrag / Self.minimizeFadeDistance, 0), 1))
    }

    /// Vertical drag on the player that hands playback to the mini player.
    ///
    /// Two things here are load-bearing, and getting either wrong makes the
    /// drag stutter rather than track the finger:
    ///
    /// **`coordinateSpace: .global`.** The gesture is attached to the
    /// player, but the offset it produces moves the player's ancestor — so
    /// in the default `.local` space the frame the translation is measured
    /// against moves with the finger. That feedback loop makes the
    /// translation oscillate. Global space is fixed, so it doesn't.
    ///
    /// **The direction is decided once.** Re-testing vertical dominance on
    /// every event means a slightly diagonal drag flips in and out of the
    /// gesture as the ratio crosses over, snapping the screen back to rest
    /// each time. It settles on the first event past `minimumDistance` and
    /// stays settled until the finger lifts.
    ///
    /// Attached as a *simultaneous* gesture so the transport controls
    /// underneath keep working; the seek scrubber's drag is horizontal, so
    /// the one-time dominance check is what keeps the two apart.
    private var minimizeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard store.isPlaying else { return }
                if isMinimizeDrag == nil {
                    isMinimizeDrag = value.translation.height > 0
                        && value.translation.height > abs(value.translation.width)
                }
                guard isMinimizeDrag == true else { return }
                // Clamped rather than reset: pulling back up above the
                // start should settle the screen at rest, not re-arm.
                minimizeDrag = max(0, value.translation.height)
            }
            .onEnded { value in
                defer { isMinimizeDrag = nil }
                guard store.isPlaying, isMinimizeDrag == true else {
                    minimizeDrag = 0
                    return
                }
                let committed = value.translation.height > Self.minimizeCommitDistance
                    || value.predictedEndTranslation.height > Self.minimizeFlickDistance
                if committed {
                    HapticFeedback.light.play()
                    minimizeDrag = 0
                    send(.minimizeRequested)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        minimizeDrag = 0
                    }
                }
            }
    }

    public var body: some View {
        if childModeEnabled {
            ChildVideoPlayerScreen(store: store)
        } else {
            standardBody
        }
    }

    @ViewBuilder
    private var standardBody: some View {
        GeometryReader { geo in
            let leftColumnWidth = isCompact ? geo.size.width : geo.size.width * 0.65
            let inlineHeight = leftColumnWidth * 9 / 16
            let useCompactSidebar = geo.size.width < geo.size.height

            ZStack(alignment: .topLeading) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: inlineHeight)
                            .padding(.bottom, isCompact ? 0 : 8)

                        if !isCompact {
                            Divider()
                                .padding(.bottom, 8)
                        }

                        ScrollViewReader { scrollProxy in
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    contentView(descriptionFont: isCompact ? .subheadline : .body)
                                        .padding(.top, 8)

                                    if !store.comments.isEmpty || store.isLoadingComments {
                                        commentsSection
                                            .padding(.vertical, isCompact ? 8 : 0)
                                    }

                                    if isCompact {
                                        compactPlayNextSection
                                            .padding(.vertical, 8)

                                        if !store.nextVideos.isEmpty {
                                            compactNextUpSection
                                                .padding(.vertical, 8)
                                        }

                                        compactSimilarSection
                                            .padding(.vertical, 16)
                                    }
                                }
                                .id("scrollTop")
                            }
                            .onChange(of: store.video.videoId) {
                                send(.videoChanged)
                                scrollProxy.scrollTo("scrollTop", anchor: .top)
                            }
                        }
                    }
                    .frame(width: isCompact ? nil : leftColumnWidth)
                    .padding(.trailing, isCompact ? 0 : 8)

                    if !isCompact {
                        Divider()
                            .padding(.horizontal, 4)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                if !store.playNextItems.isEmpty {
                                    sidebarPlayNextSection(
                                        compact: useCompactSidebar
                                    )
                                }
                                if !store.nextVideos.isEmpty {
                                    sidebarNextUpSection(
                                        compact: useCompactSidebar
                                    )
                                }
                                sidebarSimilarSection(
                                    compact: useCompactSidebar
                                )
                            }
                        }
                    }
                }

                // Player — pinned at the top-leading inline slot, overlaying
                // the `Color.clear` placeholder reserved above. Fullscreen
                // is a separate modally-presented `UIViewController`, so
                // this view only ever lays the player out inline.
                playerOrThumbnail(height: inlineHeight)
                    .frame(
                        width: isCompact ? geo.size.width : leftColumnWidth,
                        height: inlineHeight
                    )
                    .simultaneousGesture(minimizeGesture)
                    // The drag is the only way into the mini player, and a
                    // drag isn't reachable under VoiceOver or Switch
                    // Control — so expose the same hand-off as a custom
                    // action on the player.
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(
                        named: String.localised("video.minimize", table: .videos)
                    ) {
                        guard store.isPlaying else { return }
                        send(.minimizeRequested)
                    }
            }
            // Preview of the hand-off: translation, and nothing else.
            //
            // No `scaleEffect` — scaling this subtree resizes the hosted
            // `VLCPlayerHostView`, whose `layoutSubviews` reacts to a
            // bounds change by rebinding VLC's drawable, so the video
            // strobes for the length of the drag. No `opacity` either:
            // a non-opaque group composites the live video layer
            // offscreen every frame. `offset` is a render-time
            // translation, so neither the host's bounds nor its
            // compositing change.
            //
            // The translation tracks the finger 1:1; anything less feels
            // like the screen is resisting.
            .offset(y: minimizeDrag)
        }
        .background(
            Color.Brand.primary
                .opacity(minimizeBackgroundOpacity)
                .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .bottomBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    send(.dismissTapped)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.Text.primary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            send(.viewDidAppear)
            if isCompact {
                OrientationLock.shared.lockPortrait()
            }
        }
        .onDisappear {
            if isCompact {
                OrientationLock.shared.unlock()
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .modifier(PlaylistPickerPresentation(
            store: store,
            isCompact: isCompact
        ))
    }

    // MARK: - Shared Content

    func contentView(descriptionFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.video.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)

            VideoMetadataLine(
                channelThumbURL: store.channelThumbURL,
                channelName: store.video.channelName,
                viewCount: store.video.formattedViewCount,
                publishedRelative: store.video.publishedRelative
            )

            VideoInfoRow(
                qualityLabel: store.video.qualityLabel,
                fileSize: store.video.formattedFileSize,
                videoCodec: store.video.videoCodec,
                duration: store.video.durationStr,
                isCached: store.isCached
            )

            if let linkedDescription = store.video.linkedDescription {
                Text(linkedDescription)
                    .font(descriptionFont)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(store.isDescriptionExpanded ? nil : 5)
                    .padding(.top, 4)

                Button {
                    send(.toggleDescription, animation: .default)
                } label: {
                    Text(
                        store.isDescriptionExpanded
                            ? String.localised(
                                "generic.showLess",
                                table: .generic
                            )
                            : String.localised(
                                "generic.showMore",
                                table: .generic
                            )
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Accent.dark)
                }
            }

            ActionButtonsRow(
                likes: store.video.formattedLikeCount,
                dislikes: store.video.formattedDislikeCount,
                isWatched: store.isWatched,
                showPlayNext: store.showPlayNext,
                isInPlayNext: store.playNextItems.contains(
                    where: { $0.videoId == store.video.videoId }
                ),
                youtubeURL: store.youtubeURL,
                tubeArchivistURL: store.tubeArchivistURL,
                isDownloading: store.isDownloading,
                isDownloaded: store.isDownloaded,
                downloadProgress: store.downloadProgress,
                onToggleWatched: { send(.toggleWatchedTapped) },
                onAddToPlayNext: { send(.addToPlayNextTapped) },
                onAddToPlaylist: { send(.addToPlaylistTapped) },
                onDownload: { send(.downloadTapped) },
                onDeleteDownload: { send(.deleteDownloadTapped) },
                onDeleteFromServer: {
                    send(.deleteFromServerTapped)
                }
            )
        }
        .padding(16)
    }

    // MARK: - Empty State

    var emptyStateSimilar: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle.on.rectangle")
                .scaledSystemFont(size: 32, relativeTo: .title)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(Color.Brand.secondary)
            Text(String.localised("video.empty.noSimilar", table: .videos))
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Playlist Picker Presentation

/// Uses `.sheet` on compact and `.popover` on regular size class.
private struct PlaylistPickerPresentation: ViewModifier {
    @Bindable var store: StoreOf<VideoDetailReducer>
    let isCompact: Bool

    func body(content: Content) -> some View {
        if isCompact {
            content.sheet(
                item: $store.scope(
                    state: \.playlistPicker,
                    action: \.playlistPicker
                )
            ) { pickerStore in
                PlaylistPickerScreen(store: pickerStore)
            }
        } else {
            content.popover(
                item: $store.scope(
                    state: \.playlistPicker,
                    action: \.playlistPicker
                )
            ) { pickerStore in
                PlaylistPickerScreen(store: pickerStore)
                    .frame(idealWidth: 400, idealHeight: 500)
            }
        }
    }
}
#endif
