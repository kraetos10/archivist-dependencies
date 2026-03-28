#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchVideoRow: View {
    let title: String
    let thumbPath: String?
    let thumbURL: URL?
    let config: ServerConfig
    let videoId: String
    let isWatched: Bool
    let watchProgress: Double
    let durationStr: String?
    let remainingStr: String?
    var onEllipsisTapped: (() -> Void)?

    public init(
        title: String,
        thumbPath: String?,
        config: ServerConfig,
        videoId: String,
        isWatched: Bool,
        watchProgress: Double,
        durationStr: String?,
        remainingStr: String?,
        onEllipsisTapped: (() -> Void)? = nil
    ) {
        self.title = title
        self.thumbPath = thumbPath
        self.thumbURL = nil
        self.config = config
        self.videoId = videoId
        self.isWatched = isWatched
        self.watchProgress = watchProgress
        self.durationStr = durationStr
        self.remainingStr = remainingStr
        self.onEllipsisTapped = onEllipsisTapped
    }

    public init(
        title: String,
        thumbURL: URL?,
        config: ServerConfig,
        videoId: String,
        isWatched: Bool,
        watchProgress: Double,
        durationStr: String?,
        remainingStr: String?,
        onEllipsisTapped: (() -> Void)? = nil
    ) {
        self.title = title
        self.thumbPath = nil
        self.thumbURL = thumbURL
        self.config = config
        self.videoId = videoId
        self.isWatched = isWatched
        self.watchProgress = watchProgress
        self.durationStr = durationStr
        self.remainingStr = remainingStr
        self.onEllipsisTapped = onEllipsisTapped
    }

    private var subtitleText: String? {
        if watchProgress > 0, let remainingStr {
            return remainingStr
        }
        return durationStr
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbPath {
            WatchThumbnail(
                path: thumbPath,
                config: config,
                width: 70
            )
        } else {
            WatchThumbnail(
                url: thumbURL,
                config: config,
                width: 70
            )
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                thumbnail

                Spacer()

                HStack(spacing: 8) {
                    if isWatched {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }

                    WatchDownloadedBadge(videoId: videoId)

                    if let onEllipsisTapped {
                        Button {
                            onEllipsisTapped()
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(title)
                .font(.headline)
                .lineLimit(2)

            if let subtitleText {
                Text(subtitleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if watchProgress > 0 {
                ProgressView(value: watchProgress)
                    .tint(.accentColor)
            }
        }
        .padding(.vertical, 8)
    }
}
#endif
