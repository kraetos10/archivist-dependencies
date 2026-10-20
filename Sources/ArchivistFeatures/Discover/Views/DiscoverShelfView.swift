#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// A titled row of videos that scrolls sideways.
struct DiscoverShelfView: View {
    let shelf: DiscoverShelf
    let status: (YouTubeVideo) -> DiscoverReducer.State.ItemStatus?
    let isPending: (YouTubeVideo) -> Bool
    let onAdd: (YouTubeVideo, _ startNow: Bool) -> Void
    let onChannelTapped: (YouTubeVideo) -> Void

    private static let cardWidth: CGFloat = 270

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(shelf.title)
                .font(.title3.bold())
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(shelf.videos) { video in
                        DiscoverVideoCard(
                            video: video,
                            status: status(video),
                            isPending: isPending(video),
                            showsChannel: true,
                            onAdd: { onAdd(video, $0) },
                            onChannelTapped: { onChannelTapped(video) }
                        )
                        .frame(width: Self.cardWidth)
                    }
                }
            }
            .scrollIndicators(.hidden)
            // Bleeds to the screen's edges, so the row doesn't look cut off
            // at the page's own padding.
            .padding(.horizontal, -16)
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }
}
#endif
