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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(filter.label, systemImage: filter.icon)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: 12) {
                    // Loop the available placeholder list up to the carousel
                    // cap so the redacted row looks the same as the real one.
                    ForEach(0..<HomeFilterSection.maxItems, id: \.self) { index in
                        let placeholders = VideoResponse.placeholders
                        let video = placeholders[index % placeholders.count]
                        VideoCardView(video: video, serverConfig: serverConfig)
                            .frame(width: cardWidth)
                            .redacted(reason: .placeholder)
                            .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollDisabled(true)
            .scrollClipDisabled()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Surface.highlight)
        )
        .padding(.horizontal, 12)
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
    var onToggleWatched: (VideoResponse) -> Void
    var onDeleteFromServer: (VideoResponse) -> Void
    var onViewAll: () -> Void

    static let maxItems = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            .padding(.top, 12)

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
                                isWatched: item.video.isWatched,
                                onPlayNext: { onPlayNext(item.video) },
                                onAddToPlaylist: { onAddToPlaylist(item.video) },
                                onDownloadToDevice: { onDownloadToDevice(item.video) },
                                onDeleteFromDevice: item.isDownloaded ? {
                                    onDeleteFromDevice(item.video)
                                } : nil,
                                onToggleWatched: { onToggleWatched(item.video) },
                                onDeleteFromServer: { onDeleteFromServer(item.video) }
                            )
                        }
                        .pressable { onVideoTapped(item.video) }
                    }

                    viewAllCard
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Surface.highlight)
        )
        .padding(.horizontal, 12)
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
