#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchVideoRow: View {
    let model: WatchVideoRowModel
    let config: ServerConfig
    let onMoreTapped: (() -> Void)?

    public init(
        model: WatchVideoRowModel,
        config: ServerConfig,
        onMoreTapped: (() -> Void)? = nil
    ) {
        self.model = model
        self.config = config
        self.onMoreTapped = onMoreTapped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                WatchThumbnail(
                    url: model.thumbnailURL,
                    config: config,
                    width: 70
                )

                Spacer()

                HStack(spacing: 8) {
                    if model.isWatched {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .accessibilityLabel(String(localized: "video.watched", bundle: .module))
                    }

                    WatchDownloadedBadge(isDownloaded: model.isDownloaded)

                    if let onMoreTapped {
                        Button(
                            String(localized: "action.moreOptions", bundle: .module),
                            systemImage: "ellipsis",
                            action: onMoreTapped
                        )
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Text(model.title)
                .font(.headline)
                .lineLimit(2)

            if let subtitle = model.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if model.watchProgress > 0 {
                ProgressView(value: model.watchProgress)
                    .tint(.accentColor)
            }
        }
        .padding(.vertical, 8)
    }
}
#endif
