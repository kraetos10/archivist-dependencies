#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import SwiftUI

public struct TVVideoCardView: View {
    let data: CardData
    let serverConfig: ServerConfig
    var onTap: (() -> Void)?

    public init(
        video: VideoResponse,
        serverConfig: ServerConfig,
        onTap: (() -> Void)? = nil
    ) {
        self.data = video.cardData
        self.serverConfig = serverConfig
        self.onTap = onTap
    }

    public init(
        download: DownloadResponse,
        serverConfig: ServerConfig,
        onTap: (() -> Void)? = nil
    ) {
        self.data = download.cardData
        self.serverConfig = serverConfig
        self.onTap = onTap
    }

    @FocusState private var isFocused: Bool

    public var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
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
        ZStack(alignment: .bottomTrailing) {
            if let thumbURL = thumbnailURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
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

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if let durationStr = data.duration {
                        Text(durationStr)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, data.watchProgress > 0 ? 4 : 12)
                    }
                }

                if data.watchProgress > 0 {
                    WatchProgressBar(progress: data.watchProgress, height: 6)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(data.title)
                .font(.headline)
                .lineLimit(1)

            if let channelName = data.channelName {
                Text(channelName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let published = data.publishedRelative {
                Text(published)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .aspectRatio(16 / 9, contentMode: .fill)
    }

    private var thumbnailURL: URL? {
        guard let thumbPath = data.thumbPath else { return nil }
        return serverConfig.fullURL(for: thumbPath)
    }
}
#endif
