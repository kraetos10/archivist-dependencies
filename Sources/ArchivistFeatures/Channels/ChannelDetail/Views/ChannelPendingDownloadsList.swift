#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The channel's queued-but-not-yet-downloaded videos.
struct ChannelPendingDownloadsList: View {
    let store: StoreOf<ChannelDetailReducer>

    var body: some View {
        VStack(spacing: 0) {
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
        }
        .padding(.bottom, 24)
    }
}
#endif
