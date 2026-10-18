#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The home page's Queue strip: videos waiting in the server's download
/// queue, in the Queue screen's order. Laid out like the other home
/// carousels, but marked as not available yet — a dashed outline, a line
/// saying so, and a download badge on each card. Tapping a card downloads
/// it now; View All opens the Queue screen.
struct HomeQueueSection: View {
    let downloads: [DownloadResponse]
    let serverConfig: ServerConfig
    let cardWidth: CGFloat
    var onDownloadTapped: (DownloadResponse) -> Void
    var onViewAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(
                        String.localised("video.downloadQueue", table: .videos),
                        systemImage: "tray.and.arrow.down"
                    )
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                    .accessibilityAddTraits(.isHeader)

                    Text(String.localised("video.downloadQueue.hint", table: .videos))
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
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

            ScrollView(.horizontal) {
                LazyHStack(alignment: .center, spacing: 12) {
                    ForEach(downloads) { download in
                        VideoCardView(
                            download: download,
                            serverConfig: serverConfig
                        )
                        .frame(width: cardWidth)
                        .pressable { onDownloadTapped(download) }
                        .accessibilityHint(String.localised("video.downloadNow", table: .videos))
                    }

                    viewAllCard
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
        }
        // The dashed outline is drawn behind the cards, not over them.
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Surface.highlight.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            Color.Brand.secondary.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                )
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
    }

    /// The same trailing View All as the other home carousels.
    private var viewAllCard: some View {
        Button(action: onViewAll) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .scaledSystemFont(size: 32, relativeTo: .title)
                    .accessibilityHidden(true)
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
