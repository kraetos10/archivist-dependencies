#if os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct TVChannelCardView: View {
    public let channel: ChannelResponse
    public let serverConfig: ServerConfig
    public let hasNewContent: Bool
    public var action: () -> Void = {}

    @FocusState private var isFocused: Bool

    public init(
        channel: ChannelResponse,
        serverConfig: ServerConfig,
        hasNewContent: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.channel = channel
        self.serverConfig = serverConfig
        self.hasNewContent = hasNewContent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                thumbnailView
                infoView
            }
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: isFocused ? .white.opacity(0.5) : .clear, radius: isFocused ? 20 : 0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var thumbnailView: some View {
        ChannelThumbView(url: thumbnailURL, size: 120)
            .overlay(alignment: .topTrailing) {
                if hasNewContent {
                    Circle()
                        .fill(Color.Accent.dark)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(.black.opacity(0.3), lineWidth: 2)
                        )
                        .offset(x: 2, y: -2)
                }
            }
    }

    private var infoView: some View {
        VStack(spacing: 6) {
            Text(channel.channelName)
                .font(.headline)
                .lineLimit(1)

            if let subs = channel.formattedSubs {
                Text(String.localised("\(subs) subscribers"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thumbnailURL: URL? {
        guard let thumbPath = channel.channelThumbUrl else { return nil }
        return serverConfig.fullURL(for: thumbPath)
    }
}
#endif
