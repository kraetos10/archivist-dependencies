import ArchivistNetworking
import SwiftUI

public struct CardData {
    public let title: String
    public let channelName: String?
    public let thumbPath: String?
    public let duration: String?
    public let publishedRelative: String?
    public let isWatched: Bool
    public let isPartiallyWatched: Bool
    public let watchProgress: Double
    public let isPending: Bool
    public var isDownloaded: Bool
    public let fileSize: String?

    public init(
        title: String,
        channelName: String?,
        thumbPath: String?,
        duration: String?,
        publishedRelative: String?,
        isWatched: Bool,
        isPartiallyWatched: Bool,
        watchProgress: Double,
        isPending: Bool,
        isDownloaded: Bool = false,
        fileSize: String? = nil
    ) {
        self.title = title
        self.channelName = channelName
        self.thumbPath = thumbPath
        self.duration = duration
        self.publishedRelative = publishedRelative
        self.isWatched = isWatched
        self.isPartiallyWatched = isPartiallyWatched
        self.watchProgress = watchProgress
        self.isPending = isPending
        self.isDownloaded = isDownloaded
        self.fileSize = fileSize
    }
}

public extension VideoResponse {
    var cardData: CardData {
        CardData(
            title: title,
            channelName: channelName,
            thumbPath: vidThumbUrl,
            duration: durationStr,
            publishedRelative: publishedRelative,
            isWatched: isWatched,
            isPartiallyWatched: isPartiallyWatched,
            watchProgress: watchProgress,
            isPending: false
        )
    }
}

public extension DownloadResponse {
    var cardData: CardData {
        CardData(
            title: title ?? youtubeId,
            channelName: channelName,
            thumbPath: vidThumbUrl,
            duration: duration,
            publishedRelative: publishedRelative,
            isWatched: false,
            isPartiallyWatched: false,
            watchProgress: 0,
            isPending: true
        )
    }
}

#if !os(tvOS)
public struct VideoCardView: View {
    public let data: CardData
    public let serverConfig: ServerConfig

    public init(
        video: VideoResponse,
        serverConfig: ServerConfig,
        isDownloaded: Bool = false
    ) {
        var data = video.cardData
        data.isDownloaded = isDownloaded
        self.data = data
        self.serverConfig = serverConfig
    }

    public init(
        download: DownloadResponse,
        serverConfig: ServerConfig
    ) {
        self.data = download.cardData
        self.serverConfig = serverConfig
    }

    public init(
        data: CardData,
        serverConfig: ServerConfig
    ) {
        self.data = data
        self.serverConfig = serverConfig
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailView
            infoView
        }
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        // Fully watched videos look subdued so the unwatched ones in the
        // channel detail's "All" filter stand out at a glance.
        .opacity(data.isWatched ? 0.55 : 1)
    }

    private var thumbnailView: some View {
        ZStack {
            // Black backdrop fills any letterbox / pillarbox gaps when the
            // thumbnail's native aspect isn't 16:9 (e.g. Shorts stacked
            // vertically). Without this the green card surface shows through
            // and cards look uneven.
            Color.black

            if let thumbURL = thumbnailURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
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

            VStack {
                HStack {
                    if data.isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    } else if data.isPartiallyWatched {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                    Spacer()
                    if data.isDownloaded {
                        Image(systemName: "iphone")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                }

                Spacer()

                VStack(spacing: 0) {
                    HStack(alignment: .bottom) {
                        Spacer()

                        if let durationStr = data.duration {
                            Text(durationStr)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                                .padding(.bottom, data.watchProgress > 0 ? 4 : 8)
                        }
                    }

                    if data.watchProgress > 0 {
                        WatchProgressBar(progress: data.watchProgress)
                    }
                }

            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)

            if let channelName = data.channelName {
                Text(channelName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(Color.Brand.secondary)
            }

            HStack(spacing: 6) {
                if data.isPending {
                    Text(String.localised("generic.pending", table: .generic))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.Accent.dark)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if let fileSize = data.fileSize {
                    Text(fileSize)
                        .font(.caption2)
                        .foregroundStyle(Color.Brand.secondary)
                }

                if let published = data.publishedRelative {
                    Text(published)
                        .font(.caption2)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color.Brand.secondary.opacity(0.3))
            .aspectRatio(16 / 9, contentMode: .fill)
    }

    private var thumbnailURL: URL? {
        guard let thumbPath = data.thumbPath else { return nil }
        return serverConfig.fullURL(for: thumbPath)
    }
}

#Preview {
    VideoCardView(
        video: .placeholder,
        serverConfig: ServerConfig(baseURL: "localhost", apiToken: "preview")
    )
    .padding()
    .background(Color.Brand.primary)
}
#endif

public struct PressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

public extension View {
    func pressable(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
        }
        .buttonStyle(PressableButtonStyle())
    }
}
