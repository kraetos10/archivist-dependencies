#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Pinned header over the channel's pending-downloads list, with the
/// newest/oldest sort toggle.
@ViewAction(for: ChannelDetailReducer.self)
struct ChannelDownloadsSectionHeader: View {
    let store: StoreOf<ChannelDetailReducer>

    var body: some View {
        HStack {
            Text(String.localised("video.pendingDownloads", table: .videos))
                .font(.headline)
                .foregroundStyle(Color.Text.primary)

            Spacer()

            Button {
                send(.downloadSortToggled, animation: .default)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
#endif
