import SwiftUI

public struct VideoMetadataLine: View {
    let channelThumbURL: URL?
    let channelName: String
    let viewCount: String?
    let publishedRelative: String?

    public init(
        channelThumbURL: URL?,
        channelName: String,
        viewCount: String?,
        publishedRelative: String?
    ) {
        self.channelThumbURL = channelThumbURL
        self.channelName = channelName
        self.viewCount = viewCount
        self.publishedRelative = publishedRelative
    }

    public var body: some View {
        HStack(spacing: 6) {
            ChannelThumbView(url: channelThumbURL)

            Text(channelName)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)

            if let views = viewCount {
                Text("·")
                Text("\(views) views")
            }

            if let published = publishedRelative {
                Text("·")
                Text(published)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.Brand.secondary)
        .lineLimit(1)
    }
}
