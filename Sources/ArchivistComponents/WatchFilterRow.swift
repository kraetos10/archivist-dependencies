#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct WatchFilterRow: View {
    public let watchFilter: WatchFilter
    public let showDownloadedOnly: Bool
    public let onFilterChanged: (WatchFilter) -> Void
    public let onDownloadedFilterTapped: () -> Void

    public init(
        watchFilter: WatchFilter,
        showDownloadedOnly: Bool,
        onFilterChanged: @escaping (WatchFilter) -> Void,
        onDownloadedFilterTapped: @escaping () -> Void
    ) {
        self.watchFilter = watchFilter
        self.showDownloadedOnly = showDownloadedOnly
        self.onFilterChanged = onFilterChanged
        self.onDownloadedFilterTapped = onDownloadedFilterTapped
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WatchFilter.allCases, id: \.self) { filter in
                    let isSelected = watchFilter == filter && !showDownloadedOnly
                    Button {
                        HapticFeedback.selection.play()
                        onFilterChanged(filter)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(.caption)
                            Text(filter.label)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.Brand.primary : Color.Text.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.Text.primary : Color.Surface.highlight)
                        .clipShape(Capsule())
                    }
                }

                Button {
                    HapticFeedback.selection.play()
                    onDownloadedFilterTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption)
                        Text(String.localised("video.downloaded", table: .videos))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(showDownloadedOnly ? Color.Brand.primary : Color.Text.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(showDownloadedOnly ? Color.Text.primary : Color.Surface.highlight)
                    .clipShape(Capsule())
                }
            }
        }
        .contentMargins(.horizontal, 16)
    }
}
#endif
