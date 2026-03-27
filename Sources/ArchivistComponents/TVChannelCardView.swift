import ArchivistNetworking
import SwiftUI

public struct TVChannelCardView: View {
    public let channel: ChannelResponse
    public let serverConfig: ServerConfig
    public var action: () -> Void = {}

    @FocusState private var isFocused: Bool

    public init(channel: ChannelResponse, serverConfig: ServerConfig, action: @escaping () -> Void = {}) {
        self.channel = channel
        self.serverConfig = serverConfig
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                thumbnailView
                infoView
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .shadow(color: isFocused ? .white.opacity(0.4) : .black.opacity(0.3), radius: isFocused ? 24 : 4)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var thumbnailView: some View {
        Group {
            if let thumbURL = thumbnailURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    case .failure:
                        thumbnailPlaceholder
                    case .empty:
                        thumbnailPlaceholder
                            .overlay { ProgressView() }
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
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

    private var thumbnailPlaceholder: some View {
        Circle()
            .fill(.secondary.opacity(0.3))
            .frame(width: 120, height: 120)
    }

    private var thumbnailURL: URL? {
        guard let thumbPath = channel.channelThumbUrl else { return nil }
        return serverConfig.fullURL(for: thumbPath)
    }
}
