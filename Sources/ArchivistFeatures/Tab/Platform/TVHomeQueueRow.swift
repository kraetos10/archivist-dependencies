#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// The tvOS home screen's Queue row: videos waiting in the server's
/// download queue. The same cards as the video rows, greyed out with a
/// download badge and a line under the title saying they can't be watched
/// yet. Selecting one downloads it now; View All opens the Queue screen.
struct TVHomeQueueRow: View {
    let downloads: [DownloadResponse]
    let serverConfig: ServerConfig
    let focus: FocusState<TVHomeFocus?>.Binding
    let onDownloadTapped: (DownloadResponse) -> Void
    let onViewAll: () -> Void

    var body: some View {
        TVHomeSectionContainer(
            title: String.localised("video.downloadQueue", table: .videos),
            icon: "tray.and.arrow.down",
            subtitle: String.localised("video.downloadQueue.hint", table: .videos)
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                    ForEach(downloads) { download in
                        TVVideoCardView(
                            download: download,
                            serverConfig: serverConfig
                        ) {
                            onDownloadTapped(download)
                        }
                        .frame(width: TVLayout.cardWidth)
                        .focused(focus, equals: .card(.queue, id: download.youtubeId))
                    }

                    if !downloads.isEmpty {
                        TVHomeViewAllCard(action: onViewAll)
                            .focused(focus, equals: .viewAll(.queue))
                    }
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .scrollClipDisabled()
        }
    }
}
#endif
