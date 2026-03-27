import ArchivistNetworking
import SwiftUI

public struct ChannelCardView: View {
    public let channel: ChannelResponse
    public let serverConfig: ServerConfig

    public init(channel: ChannelResponse, serverConfig: ServerConfig) {
        self.channel = channel
        self.serverConfig = serverConfig
    }

    public var body: some View {
        VStack(spacing: 12) {
            thumbnailView
            infoView
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
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
                            .overlay {
                                ProgressView()
                                    .tint(Color.Progress.tint)
                            }
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
    }

    private var infoView: some View {
        VStack(spacing: 4) {
            Text(channel.channelName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            if let subs = channel.formattedSubs {
                Text(String.localised("\(subs) subscribers"))
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
        .padding(.horizontal, 12)
    }

    private var thumbnailPlaceholder: some View {
        Circle()
            .fill(Color.Brand.secondary.opacity(0.3))
            .frame(width: 80, height: 80)
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
