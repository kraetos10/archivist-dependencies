#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// Horizontal carousel of the channel's videos, plus its loading and empty
/// states.
@ViewAction(for: ChannelDetailReducer.self)
struct ChannelVideosCarousel: View {
    let store: StoreOf<ChannelDetailReducer>

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var videoCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 300 : 260
    }

    var body: some View {
        VStack(spacing: 12) {
            if store.isLoadingVideos && store.videos.isEmpty {
                loadingCarousel
            } else if store.filteredVideos.isEmpty && store.hasLoadedVideos {
                emptyState
            } else {
                carousel
            }
        }
        .padding(.bottom, 8)
    }

    private var loadingCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(VideoResponse.placeholders.prefix(4)) { video in
                    VideoCardView(
                        video: video,
                        serverConfig: store.serverConfig
                    )
                    .frame(width: videoCardWidth)
                    .redacted(reason: .placeholder)
                }
            }
            .padding(.vertical, 8)
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .contentMargins(.horizontal, 16)
        .scrollTargetBehavior(.viewAligned)
    }

    /// Sized off a hidden card so the empty message occupies the same slot
    /// the carousel would, keeping the section height stable.
    private var emptyState: some View {
        VideoCardView(
            video: .placeholder,
            serverConfig: store.serverConfig
        )
        .frame(width: videoCardWidth)
        .hidden()
        .overlay {
            Text(store.videoFilter == .unwatched
                 ? String(localized: "No unwatched videos")
                 : String.localised("video.empty.noVideos", table: .videos))
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(store.filteredVideos) { video in
                    VideoCardView(
                        video: video,
                        serverConfig: store.serverConfig
                    )
                    .frame(width: videoCardWidth)
                    .contextMenu {
                        VideoContextMenu(
                            youtubeURL: video.youtubeURL,
                            isWatched: video.isWatched,
                            onPlayNext: { send(.playNextTapped(video), animation: .default) },
                            onAddToPlaylist: {},
                            onDownloadToDevice: { send(.downloadToDeviceTapped(video)) },
                            onToggleWatched: { send(.markAsWatchedTapped(video)) },
                            onDeleteFromServer: { send(.deleteFromServerTapped(video)) }
                        )
                    }
                    .pressable {
                        send(.videoCardTapped(video))
                    }
                    .onAppear {
                        if video.id == store.videos.last?.id {
                            send(.lastVideoAppeared)
                        }
                    }
                }

                if store.isLoadingMoreVideos {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .frame(width: 60)
                }
            }
            .padding(.vertical, 8)
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .contentMargins(.horizontal, 16)
        .scrollTargetBehavior(.viewAligned)
    }
}
#endif
