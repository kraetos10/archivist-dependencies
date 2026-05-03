import ArchivistNetworking
import SwiftUI

public struct PlayNextRowView: View {
    public let title: String
    public let channelName: String
    public let thumbUrl: String?
    public let duration: String?
    public let serverConfig: ServerConfig
    public let onRemove: () -> Void

    public init(
        title: String,
        channelName: String,
        thumbUrl: String?,
        duration: String?,
        serverConfig: ServerConfig,
        onRemove: @escaping () -> Void
    ) {
        self.title = title
        self.channelName = channelName
        self.thumbUrl = thumbUrl
        self.duration = duration
        self.serverConfig = serverConfig
        self.onRemove = onRemove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(1)

                Text(channelName)
                    .font(.caption2)
                    .foregroundStyle(Color.Brand.secondary)
                    .lineLimit(1)

                if let duration {
                    Text(duration)
                        .font(.caption2)
                        .foregroundStyle(Color.Brand.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label(String.localised("generic.remove", table: .generic), systemImage: "minus.circle")
            }
        }
    }

    private var thumbnail: some View {
        Group {
            if let thumbPath = thumbUrl,
               let thumbURL = serverConfig.fullURL(for: thumbPath) {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color.Brand.secondary.opacity(0.3))
                            .aspectRatio(16 / 9, contentMode: .fill)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.Brand.secondary.opacity(0.3))
                    .aspectRatio(16 / 9, contentMode: .fill)
            }
        }
    }
}
