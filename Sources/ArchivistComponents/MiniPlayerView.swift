#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct MiniPlayerView: View {
    public let title: String
    public let channelName: String
    public let thumbUrl: String?
    public let serverConfig: ServerConfig
    public let isPlaying: Bool
    public let isInPiP: Bool
    public let onTap: () -> Void
    public let onPlayPause: () -> Void
    public let onClose: () -> Void

    public init(
        title: String,
        channelName: String,
        thumbUrl: String?,
        serverConfig: ServerConfig,
        isPlaying: Bool,
        isInPiP: Bool,
        onTap: @escaping () -> Void,
        onPlayPause: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.channelName = channelName
        self.thumbUrl = thumbUrl
        self.serverConfig = serverConfig
        self.isPlaying = isPlaying
        self.isInPiP = isInPiP
        self.onTap = onTap
        self.onPlayPause = onPlayPause
        self.onClose = onClose
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Show live video when PiP is not active, thumbnail otherwise.
                // Creating a second AVPlayerViewController while PiP is active
                // on the original VC would kill the PiP session.
                if isInPiP {
                    thumbnail
                } else {
                    AVPlayerViewControllerWrapper()
                        .frame(width: 64, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .allowsHitTesting(false)
                }

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.Surface.highlight)
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    let progress = PlayerManager.shared.duration > 0
                        ? PlayerManager.shared.currentTime / PlayerManager.shared.duration
                        : 0
                    Rectangle()
                        .fill(Color.Accent.dark)
                        .frame(width: geo.size.width * progress, height: 2)
                }
                .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        Group {
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
                .frame(width: 64, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Rectangle()
                    .fill(Color.Brand.secondary.opacity(0.3))
                    .frame(width: 64, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
#endif
