#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct SimilarVideoRow: View {
    public let video: VideoResponse
    public let serverConfig: ServerConfig
    public let compact: Bool

    public init(
        video: VideoResponse,
        serverConfig: ServerConfig,
        compact: Bool = false
    ) {
        self.video = video
        self.serverConfig = serverConfig
        self.compact = compact
    }

    public var body: some View {
        Group {
            if compact {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipped()

            details
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            thumbnail
                .frame(width: 160, height: 90)
                .clipped()

            details
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
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
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color.Brand.secondary.opacity(0.3))
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.Brand.secondary.opacity(0.3))
            }

            if video.watchProgress > 0 {
                VStack {
                    Spacer()
                    WatchProgressBar(progress: video.watchProgress, height: 3)
                }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(video.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)

            Text(video.channelName)
                .font(.caption2)
                .foregroundStyle(Color.Brand.secondary)
                .lineLimit(1)

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
}
#endif
