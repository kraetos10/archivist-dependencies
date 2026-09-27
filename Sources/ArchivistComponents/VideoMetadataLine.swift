import SwiftUI

public struct VideoMetadataLine: View {
    let channelThumbURL: URL?
    let channelName: String
    let viewCount: String?
    let publishedRelative: String?
    /// Makes the channel thumbnail and name a button, when set.
    let onChannelTapped: (() -> Void)?

    public init(
        channelThumbURL: URL?,
        channelName: String,
        viewCount: String?,
        publishedRelative: String?,
        onChannelTapped: (() -> Void)? = nil
    ) {
        self.channelThumbURL = channelThumbURL
        self.channelName = channelName
        self.viewCount = viewCount
        self.publishedRelative = publishedRelative
        self.onChannelTapped = onChannelTapped
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let onChannelTapped {
                Button(action: onChannelTapped) {
                    channel
                }
                .buttonStyle(.plain)
                .accessibilityHint(String.localised("video.openChannelHint", table: .videos))
            } else {
                channel
            }

            if let views = viewCount {
                Text("·")
                    .accessibilityHidden(true)
                Text(String.localised("\(views) views"))
            }

            if let published = publishedRelative {
                Text("·")
                    .accessibilityHidden(true)
                Text(published)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.Brand.secondary)
        .lineLimit(1)
    }

    private var channel: some View {
        HStack(spacing: 6) {
            ChannelThumbView(url: channelThumbURL)

            Text(channelName)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
        }
        .contentShape(Rectangle())
    }
}
