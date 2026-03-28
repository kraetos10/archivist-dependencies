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

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var playerWidth: CGFloat { sizeClass == .regular ? 300 : 200 }
    private var playerHeight: CGFloat { sizeClass == .regular ? 169 : 113 }

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
        ZStack {
            livePlayer
                .allowsHitTesting(false)

            // Invisible tap layer that covers the player
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .overlay(alignment: .bottom) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                let progress = PlayerManager.shared.duration > 0
                    ? PlayerManager.shared.currentTime / PlayerManager.shared.duration
                    : 0
                Rectangle()
                    .fill(Color.Accent.dark)
                    .frame(width: geo.size.width * progress, height: 3)
            }
            .frame(height: 3)
            .allowsHitTesting(false)
        }
        .frame(width: playerWidth, height: playerHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    @ViewBuilder
    private var livePlayer: some View {
        if PlayerManager.shared.backend is VLCPlayerBackend {
            MiniVLCPlayerView()
                .frame(width: playerWidth, height: playerHeight)
        } else if PlayerManager.shared.player != nil {
            MiniAVPlayerView()
                .frame(width: playerWidth, height: playerHeight)
        } else {
            thumbnail
        }
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
                .frame(width: playerWidth, height: playerHeight)
            } else {
                Rectangle()
                    .fill(Color.Brand.secondary.opacity(0.3))
                    .frame(width: playerWidth, height: playerHeight)
            }
        }
    }
}
#endif
