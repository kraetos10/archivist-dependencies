#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// A titled row of videos that scrolls sideways. A "because you watched"
/// row's title is a menu for basing it on a different video.
struct DiscoverShelfView: View {
    let shelf: DiscoverShelf
    /// Other videos the row can be switched to; empty for a plain row.
    let choices: [DiscoverShelf.Choice]
    let isLoading: Bool
    let status: (YouTubeVideo) -> DiscoverReducer.State.ItemStatus?
    let isPending: (YouTubeVideo) -> Bool
    let onAdd: (YouTubeVideo, _ startNow: Bool) -> Void
    let onChannelTapped: (YouTubeVideo) -> Void
    let onChoose: (DiscoverShelf.Choice) -> Void

    var body: some View {
        DiscoverRow(
            resetKey: shelf.seedId ?? shelf.id,
            header: { header },
            content: { cardWidth in
                if isLoading {
                    DiscoverCardSkeletons(cardWidth: cardWidth)
                } else {
                    ForEach(shelf.videos) { video in
                        DiscoverVideoCard(
                            video: video,
                            status: status(video),
                            isPending: isPending(video),
                            showsChannel: true,
                            onAdd: { onAdd(video, $0) },
                            onChannelTapped: { onChannelTapped(video) }
                        )
                        .frame(width: cardWidth)
                        .transition(.opacity)
                    }
                }
            }
        )
        .animation(.smooth, value: shelf)
        .animation(.smooth, value: isLoading)
    }

    @ViewBuilder
    private var header: some View {
        if choices.isEmpty {
            title
        } else {
            Menu {
                Section(String.localised("discover.shelf.choose", table: .discover)) {
                    ForEach(choices) { choice in
                        Button {
                            onChoose(choice)
                        } label: {
                            if choice.videoId == shelf.seedId {
                                Label(choice.title, systemImage: "checkmark")
                            } else {
                                Text(choice.title)
                            }
                        }
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    title
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.Accent.dark)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(String.localised("discover.shelf.choose.hint", table: .discover))
        }
    }

    private var title: some View {
        Text(shelf.title)
            .font(.headline)
            .foregroundStyle(Color.Text.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .accessibilityAddTraits(.isHeader)
            .contentTransition(.opacity)
    }
}
#endif
