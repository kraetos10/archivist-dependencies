#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Pinned header over the channel's video carousel: sort menu, watched
/// filter, and the "clear" action for the current filter.
@ViewAction(for: ChannelDetailReducer.self)
struct ChannelVideosSectionHeader: View {
    let store: StoreOf<ChannelDetailReducer>

    var body: some View {
        HStack {
            Text(String.localised("generic.videos", table: .generic))
                .font(.headline)
                .foregroundStyle(Color.Text.primary)

            Spacer()

            VideoSortMenu(current: store.videoSortOrder) { sort in
                send(.videoSortOrderChanged(sort), animation: .default)
            }

            HStack(spacing: 8) {
                filterPill(String(localized: "All"), filter: .all)
                filterPill(String(localized: "Unwatched"), filter: .unwatched)
                clearButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var clearButton: some View {
        Button {
            send(.clearFilteredTapped)
        } label: {
            Text(String.localised("video.clear", table: .videos))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.filteredVideos.isEmpty)
        .opacity(store.filteredVideos.isEmpty ? 0.4 : 1.0)
    }

    private func filterPill(_ title: String, filter: ChannelVideoFilter) -> some View {
        let isSelected = store.videoFilter == filter
        return Button {
            send(.videoFilterChanged(filter), animation: .default)
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.Text.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.Accent.dark : Color.Surface.highlight)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif
