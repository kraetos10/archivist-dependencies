import SwiftUI

public struct VideoInfoRow: View {
    let pills: [String]
    let duration: String?
    let isCached: Bool

    public init(
        qualityLabel: String?,
        fileSize: String?,
        videoCodec: String?,
        duration: String?,
        isCached: Bool = false
    ) {
        self.pills = [qualityLabel, fileSize, videoCodec].compactMap { $0 }
        self.duration = duration
        self.isCached = isCached
    }

    public var body: some View {
        let hasPills = !pills.isEmpty
        let hasDuration = duration != nil
        if hasPills || hasDuration || isCached {
            HStack(spacing: 8) {
                ForEach(pills, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.Surface.highlight)
                        .clipShape(Capsule())
                }

                if isCached {
                    Label(
                        String.localised("video.cached", table: .videos),
                        systemImage: "externaldrive.badge.checkmark"
                    )
                    .labelStyle(.iconOnly)
                    .font(.caption)
                    .foregroundStyle(Color.Accent.dark)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.Surface.highlight)
                    .clipShape(Capsule())
                    .accessibilityLabel(
                        String.localised("video.cached", table: .videos)
                    )
                }

                if (hasPills || isCached), let duration {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                } else if let duration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }
        }
    }
}
