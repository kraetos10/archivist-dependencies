#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The channel's videos as full-width cards on iPhone and a grid on iPad,
/// plus their loading and empty states. Tapping a card plays it, or picks
/// it while selecting.
@ViewAction(for: ChannelDetailReducer.self)
struct ChannelVideosGrid: View {
    let store: StoreOf<ChannelDetailReducer>

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.adaptive(minimum: 300), spacing: 16)]
            : [GridItem(.flexible())]
    }

    var body: some View {
        // Read once per pass: `filteredVideos` rebuilds the queued set and
        // filters every video.
        let visible = store.filteredVideos

        Group {
            if store.isLoadingVideos && store.videos.isEmpty {
                placeholderGrid
            } else if visible.isEmpty && store.hasLoadedVideos {
                Text(store.videoFilter.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else {
                grid(visible)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var placeholderGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(VideoResponse.placeholders.prefix(4)) { video in
                VideoCardView(
                    video: video,
                    serverConfig: store.serverConfig
                )
                .redacted(reason: .placeholder)
            }
        }
    }

    private func grid(_ videos: IdentifiedArrayOf<VideoResponse>) -> some View {
        let downloadedIDs = store.downloadedVideoIDs
        return VStack(spacing: 16) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(videos) { video in
                    card(
                        video,
                        isDownloaded: downloadedIDs.contains(video.videoId)
                    )
                    .onAppear {
                        // Anchor on the rendered list: queued and locally
                        // re-filtered videos mean the last fetched one may
                        // never be drawn.
                        if video.id == videos.last?.id {
                            send(.lastVideoAppeared)
                        }
                    }
                }
            }

            if store.isLoadingMoreVideos {
                ProgressView()
                    .tint(Color.Progress.tint)
            }
        }
    }

    private func card(
        _ video: VideoResponse,
        isDownloaded: Bool
    ) -> some View {
        let isSelected = store.selectedVideoIDs.contains(video.videoId)
        return VideoCardView(
            video: video,
            serverConfig: store.serverConfig,
            isDownloaded: isDownloaded
        )
        .overlay {
            if store.isSelecting {
                SelectionOverlay(isSelected: isSelected)
            }
        }
        .contextMenu {
            if !store.isSelecting {
                VideoContextMenu(
                    youtubeURL: video.youtubeURL,
                    isDownloaded: isDownloaded,
                    isWatched: video.isWatched,
                    onPlayNext: { send(.playNextTapped(video), animation: .default) },
                    onAddToPlaylist: { send(.addToPlaylistTapped(video)) },
                    onDownloadToDevice: { send(.downloadToDeviceTapped(video)) },
                    onDeleteFromDevice: isDownloaded
                        ? { send(.deleteFromDeviceTapped(video)) }
                        : nil,
                    onToggleWatched: { send(.markAsWatchedTapped(video), animation: .default) },
                    onDeleteFromServer: { send(.deleteFromServerTapped(video)) }
                )
            }
        }
        .pressable {
            send(.videoCardTapped(video), animation: .snappy)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Outline and check mark over a card while selecting.
private struct SelectionOverlay: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isSelected ? Color.Accent.dark : .clear, lineWidth: 3)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .scaledSystemFont(size: 24, relativeTo: .title2)
                    .foregroundStyle(isSelected ? Color.Accent.dark : Color.Text.primary)
                    .background(Circle().fill(Color.Surface.highlight))
                    .padding(12)
                    .accessibilityHidden(true)
            }
    }
}
#endif
