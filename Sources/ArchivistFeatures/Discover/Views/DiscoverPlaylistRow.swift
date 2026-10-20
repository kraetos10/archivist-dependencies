#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct DiscoverPlaylistRow: View {
    let playlist: YouTubePlaylist
    let isSubscribed: Bool
    let isPending: Bool
    let onSubscribe: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Color.Surface.highlight
                .frame(width: 120, height: 68)
                .overlay {
                    AsyncImage(url: playlist.thumbnailURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let count = playlist.itemCount {
                        Label("\(count)", systemImage: "play.rectangle.on.rectangle")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(2)
                Text(playlist.channelTitle)
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DiscoverSubscribeButton(
                isSubscribed: isSubscribed,
                isPending: isPending,
                action: onSubscribe
            )
        }
        .padding(12)
        .background(Color.Surface.highlight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}
#endif
