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
    @Bindable private var playerManager = PlayerManager.shared
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    var isCompact: Bool {
        sizeClass == .compact
    }

    /// True when the player should occupy the entire screen — driven by the
    /// fullscreen toggle on `VLCPlayerView`'s controls. Intentionally NOT
    /// gated on `store.isPlaying`: during a device rotation VLC briefly
    /// reports `isPlaying = false` while the rendering pipeline rebinds
    /// to the resized window, and using that here would yank the user
    /// out of fullscreen mid-rotation.
    private var isFullscreen: Bool {
        playerManager.isVLCFullscreen
    }

    public var body: some View {
        GeometryReader { geo in
            let leftColumnWidth = isCompact ? geo.size.width : geo.size.width * 0.65
            let inlineHeight = leftColumnWidth * 9 / 16
            let useCompactSidebar = geo.size.width < geo.size.height

            ZStack(alignment: .topLeading) {
                if !isFullscreen {
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
                    .transition(.opacity)
                }

                // Player — always at the same SwiftUI structural position.
                // Only its frame + safe-area treatment changes. SwiftUI
                // animates the frame change without re-mounting the player
                // surface, so the persistent VLC view stays bound to the
                // same window-backed layer through the transition.
                playerOrThumbnail(height: isFullscreen ? geo.size.height : inlineHeight)
                    .frame(
                        width: isFullscreen ? geo.size.width : (isCompact ? geo.size.width : leftColumnWidth),
                        height: isFullscreen ? geo.size.height : inlineHeight
                    )
                    .background(isFullscreen ? Color.black : .clear)
            }
        }
        .background(Color.Brand.primary.ignoresSafeArea())
        .ignoresSafeArea(isFullscreen ? .all : [])
        .toolbar(.hidden, for: .bottomBar)
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .navigationBarBackButtonHidden(isFullscreen)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    send(.dismissTapped)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.Text.primary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: isFullscreen)
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
                .font(.system(size: 32))
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
