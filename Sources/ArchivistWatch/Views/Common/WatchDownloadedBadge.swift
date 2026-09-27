#if os(watchOS)
import SwiftUI

public struct WatchDownloadedBadge: View {
    let isDownloaded: Bool

    public init(isDownloaded: Bool) {
        self.isDownloaded = isDownloaded
    }

    public var body: some View {
        if isDownloaded {
            Image(systemName: "arrow.down.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .accessibilityLabel(String(localized: "action.downloaded", bundle: .module))
        }
    }
}
#endif
