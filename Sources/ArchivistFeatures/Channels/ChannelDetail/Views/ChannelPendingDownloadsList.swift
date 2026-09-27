#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The channel's queued-but-not-yet-downloaded videos.
///
/// The rows are the view's direct children (no wrapping stack), so inside the
/// screen's `LazyVStack` section they're built as they scroll in rather than
/// all up front.
struct ChannelPendingDownloadsList: View {
    let store: StoreOf<ChannelDetailReducer>

    var body: some View {
        if store.isLoadingDownloads {
            ForEach(DownloadResponse.placeholders) { download in
                VideoRowView(
                    title: download.title ?? "",
                    subtitle: download.publishedRelative,
                    thumbnailURL: download.thumbURL(config: store.serverConfig)
                )
                .redacted(reason: .placeholder)
            }
        } else {
            ForEach(store.pendingDownloads) { download in
                DownloadRowWithPopover(
                    download: download,
                    store: store
                )
            }
        }

        Color.clear
            .frame(height: 24)
            .accessibilityHidden(true)
    }
}
#endif
