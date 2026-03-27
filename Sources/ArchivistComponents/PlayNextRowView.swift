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
            ZStack(alignment: .bottomTrailing) {
                if let thumbPath = thumbUrl,
                   let thumbURL = serverConfig.fullURL(for: thumbPath) {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.Brand.secondary.opacity(0.3))
                        }
                    }
                } else {
                    Rectangle().fill(Color.Brand.secondary.opacity(0.3))
                }

                if let duration {
                    Text(duration)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)

            Text(channelName)
                .font(.caption2)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(width: 200)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label(String(localized: "Remove"), systemImage: "minus.circle")
            }
        }
    }
}
