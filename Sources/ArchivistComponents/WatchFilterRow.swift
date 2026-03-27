#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct WatchFilterRow: View {
    public let watchFilter: WatchFilter
    public let onFilterChanged: (WatchFilter) -> Void

    public init(
        watchFilter: WatchFilter,
        onFilterChanged: @escaping (WatchFilter) -> Void
    ) {
        self.watchFilter = watchFilter
        self.onFilterChanged = onFilterChanged
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WatchFilter.allCases, id: \.self) { filter in
                    let isSelected = watchFilter == filter
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
            }
        }
        .contentMargins(.horizontal, 16)
    }
}
#endif
