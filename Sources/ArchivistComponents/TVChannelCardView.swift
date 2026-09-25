#if os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct TVChannelCardView: View {
    public let channel: ChannelResponse
    public let serverConfig: ServerConfig
    public var action: () -> Void = {}

    @FocusState private var isFocused: Bool

    private static let avatarSize: CGFloat = 120

    public init(
        channel: ChannelResponse,
        serverConfig: ServerConfig,
        action: @escaping () -> Void = {}
    ) {
        self.channel = channel
        self.serverConfig = serverConfig
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                thumbnailView
                    .tvCardFocusEffect(isFocused, cornerRadius: Self.avatarSize / 2)
                infoView
            }
            // A fixed width, so a long name truncates instead of widening
            // the card and throwing off the row's spacing.
            .frame(width: TVLayout.channelCardWidth)
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
    }

    private var thumbnailView: some View {
        ChannelThumbView(url: thumbnailURL, size: Self.avatarSize)
    }

    private var infoView: some View {
        VStack(spacing: 6) {
            Text(channel.channelName)
                .font(.headline)
                .lineLimit(1)

            Text(channel.formattedSubs.map { String.localised("\($0) subscribers") } ?? " ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var thumbnailURL: URL? {
        guard let thumbPath = channel.channelThumbUrl else { return nil }
        return serverConfig.fullURL(for: thumbPath)
    }
}
#endif
