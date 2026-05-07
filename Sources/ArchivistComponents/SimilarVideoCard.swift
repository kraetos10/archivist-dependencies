#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct SimilarVideoCard: View {
    public let video: VideoResponse
    public let serverConfig: ServerConfig
    /// When false, hides the duration / view-count line under the
    /// title — used by the child-mode player rail where the metadata
    /// adds noise the kid can't action on.
    public let showsStats: Bool

    public init(
        video: VideoResponse,
        serverConfig: ServerConfig,
        showsStats: Bool = true
    ) {
        self.video = video
        self.serverConfig = serverConfig
        self.showsStats = showsStats
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(1)

                Text(video.channelName)
                    .font(.caption2)
                    .foregroundStyle(Color.Brand.secondary)
                    .lineLimit(1)

                if showsStats {
                    HStack(spacing: 4) {
                        if let duration = video.durationStr {
                            Text(duration)
                        }

                        if let views = video.formattedViewCount {
                            Text("· \(views) views")
                        }
                    }
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
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbPath = video.vidThumbUrl,
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

            if video.watchProgress > 0 {
                VStack {
                    Spacer()
                    WatchProgressBar(progress: video.watchProgress, height: 3)
                }
            }
        }
    }
}
#endif
