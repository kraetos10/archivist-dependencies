#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// Redacted carousel shown while the home page's first fetch is in flight.
/// Matches the real `HomeFilterSection` so the transition to real content
/// doesn't reflow the layout.
struct HomeFilterSectionPlaceholder: View {
    let filter: WatchFilter
    let serverConfig: ServerConfig
    let cardWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(filter.label, systemImage: filter.icon)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: 12) {
                    ForEach(VideoResponse.placeholders.prefix(3)) { video in
                        VideoCardView(video: video, serverConfig: serverConfig)
                            .frame(width: cardWidth)
                            .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollDisabled(true)
            .scrollClipDisabled()
        }
        .padding(.vertical, 8)
    }
}

/// Single horizontal carousel rendered on the home page for one `WatchFilter`.
/// Shows up to `maxItems` cards, followed by a compact "View All" chevron.
struct HomeFilterSection: View {
    let filter: WatchFilter
    let items: [DisplayedVideo]
    let serverConfig: ServerConfig
    let cardWidth: CGFloat
    var onVideoTapped: (VideoResponse) -> Void
    var onPlayNext: (VideoResponse) -> Void
    var onAddToPlaylist: (VideoResponse) -> Void
    var onDownloadToDevice: (VideoResponse) -> Void
    var onDeleteFromDevice: (VideoResponse) -> Void
    var onMarkAsWatched: (VideoResponse) -> Void
    var onDeleteFromServer: (VideoResponse) -> Void
    var onViewAll: () -> Void

    static let maxItems = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(filter.label, systemImage: filter.icon)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                Button(action: onViewAll) {
                    HStack(spacing: 4) {
                        Text(String.localised("video.viewAll", table: .videos))
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.Accent.dark)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: 12) {
                    ForEach(Array(items.prefix(Self.maxItems))) { item in
                        VideoCardView(
                            video: item.video,
                            serverConfig: serverConfig,
                            isDownloaded: item.isDownloaded
                        )
                        .frame(width: cardWidth)
                        .contextMenu {
                            VideoContextMenu(
                                youtubeURL: item.video.youtubeURL,
                                isDownloaded: item.isDownloaded,
                                onPlayNext: { onPlayNext(item.video) },
                                onAddToPlaylist: { onAddToPlaylist(item.video) },
                                onDownloadToDevice: { onDownloadToDevice(item.video) },
                                onDeleteFromDevice: item.isDownloaded ? {
                                    onDeleteFromDevice(item.video)
                                } : nil,
                                onMarkAsWatched: { onMarkAsWatched(item.video) },
                                onDeleteFromServer: { onDeleteFromServer(item.video) }
                            )
                        }
                        .pressable { onVideoTapped(item.video) }
                    }

                    viewAllCard
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.vertical, 8)
    }

    /// Compact chevron + "View All" label sitting at the end of the carousel.
    /// No background — it's a plain affordance that centers vertically against
    /// the video cards via the parent `LazyHStack(alignment: .center)`.
    private var viewAllCard: some View {
        Button(action: onViewAll) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.Accent.dark)
                Text(String.localised("video.viewAll", table: .videos))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }
}
#endif
