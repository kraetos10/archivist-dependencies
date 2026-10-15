#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Pinned bar over the channel's videos: the watched filter as a row of
/// chips, with the sort menu held at the trailing edge.
@ViewAction(for: ChannelDetailReducer.self)
struct ChannelVideosSectionHeader: View {
    let store: StoreOf<ChannelDetailReducer>

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ChannelVideoFilter.allCases, id: \.self) { filter in
                        filterChip(filter)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.leading, 16)
            .accessibilityLabel(String.localised("video.filter", table: .videos))

            VideoSortMenu(current: store.videoSortOrder) { sort in
                send(.videoSortOrderChanged(sort), animation: .default)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func filterChip(_ filter: ChannelVideoFilter) -> some View {
        let isSelected = store.videoFilter == filter
        return Button {
            send(.videoFilterChanged(filter), animation: .default)
        } label: {
            Text(filter.label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.Text.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.Accent.dark : Color.Surface.highlight)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
