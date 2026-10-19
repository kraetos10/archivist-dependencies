#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct DiscoverChannelRow: View {
    let channel: YouTubeChannel
    let isSubscribed: Bool
    let isPending: Bool
    let onTapped: () -> Void
    let onSubscribe: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onTapped) {
                HStack(spacing: 12) {
                    ChannelThumbView(url: channel.thumbnailURL, size: 56)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.Text.primary)
                            .lineLimit(1)
                        if !channel.statsText.isEmpty {
                            Text(channel.statsText)
                                .font(.caption)
                                .foregroundStyle(Color.Brand.secondary)
                        }
                        if !channel.channelDescription.isEmpty {
                            Text(channel.channelDescription)
                                .font(.caption)
                                .foregroundStyle(Color.Brand.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            DiscoverSubscribeButton(
                isSubscribed: isSubscribed,
                isPending: isPending,
                action: onSubscribe
            )
        }
        .padding(12)
        .background(Color.Surface.highlight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
