#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The channel's queued-but-not-yet-downloaded videos, folded into one row
/// above the video list until opened.
///
/// The rows are the view's direct children (no wrapping stack), so inside the
/// screen's `LazyVStack` they're built as they scroll in rather than all up
/// front.
@ViewAction(for: ChannelDetailReducer.self)
struct ChannelPendingDownloadsList: View {
    let store: StoreOf<ChannelDetailReducer>

    var body: some View {
        disclosureRow

        if store.isPendingDownloadsExpanded {
            ForEach(store.pendingDownloads) { download in
                DownloadRowWithPopover(
                    download: download,
                    store: store
                )
            }
        }
    }

    private var disclosureRow: some View {
        HStack(spacing: 12) {
            Button {
                send(.pendingDownloadsToggled, animation: .default)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .accessibilityHidden(true)
                    Text(store.pendingDownloadsTitle)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(store.isPendingDownloadsExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.isPendingDownloadsExpanded {
                sortButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.Surface.highlight.opacity(0.5))
    }

    private var sortButton: some View {
        Button {
            send(.downloadSortToggled, animation: .default)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(store.showNewestDownloadsFirst
                     ? String.localised("generic.descending", table: .generic)
                     : String.localised("generic.ascending", table: .generic))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color.Text.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.Surface.highlight)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif
