import ArchivistNetworking
import SwiftUI

public struct ChannelCardView: View {
    public let channel: ChannelResponse
    public let serverConfig: ServerConfig
    public let hasNewContent: Bool

    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(
        channel: ChannelResponse,
        serverConfig: ServerConfig,
        hasNewContent: Bool = false
    ) {
        self.channel = channel
        self.serverConfig = serverConfig
        self.hasNewContent = hasNewContent
    }

    private var avatarSize: CGFloat {
        sizeClass == .regular ? 100 : 80
    }

    public var body: some View {
        VStack(spacing: 12) {
            thumbnailView
            infoView
        }
        .padding(.vertical, sizeClass == .regular ? 20 : 16)
        .frame(maxWidth: .infinity)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var thumbnailView: some View {
        ChannelThumbView(url: thumbnailURL, size: avatarSize)
            .overlay(alignment: .topTrailing) {
                if hasNewContent {
                    Circle()
                        .fill(Color.Accent.dark)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.Surface.highlight, lineWidth: 2)
                        )
                        .offset(x: 2, y: -2)
                }
            }
    }

    private var infoView: some View {
        VStack(spacing: 4) {
            Text(channel.channelName)
                .font(sizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            if let subs = channel.formattedSubs {
                Text(String.localised("\(subs) subscribers"))
                    .font(sizeClass == .regular ? .subheadline : .caption)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
        .padding(.horizontal, 12)
    }

    private var thumbnailURL: URL? {
        guard let thumbPath = channel.channelThumbUrl else { return nil }
        return serverConfig.fullURL(for: thumbPath)
    }
}

#Preview {
    ChannelCardView(
        channel: .placeholder,
        serverConfig: ServerConfig(baseURL: "localhost", apiToken: "preview")
    )
    .padding()
    .background(Color.Brand.primary)
}
