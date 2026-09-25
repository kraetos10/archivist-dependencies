#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeVideoRow: View {
    let row: TVHomeRow
    let title: String
    let icon: String
    let videos: [VideoResponse]
    let serverConfig: ServerConfig
    let focus: FocusState<TVHomeFocus?>.Binding
    let onVideoTapped: (VideoResponse) -> Void
    let onMarkWatched: (VideoResponse) -> Void
    let onDelete: (VideoResponse) -> Void
    let onViewAll: () -> Void

    var body: some View {
        TVHomeSectionContainer(
            title: title,
            icon: icon
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                    ForEach(videos, id: \.videoId) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: serverConfig
                        ) {
                            onVideoTapped(video)
                        }
                        .frame(width: TVLayout.cardWidth)
                        .tvVideoContextMenu(
                            video: video,
                            onMarkWatched: { onMarkWatched(video) },
                            onDelete: { onDelete(video) }
                        )
                        .focused(focus, equals: .card(row, id: video.videoId))
                    }

                    if !videos.isEmpty {
                        TVHomeViewAllCard(action: onViewAll)
                            .focused(focus, equals: .viewAll(row))
                    }
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .scrollClipDisabled()
        }
    }
}

extension View {
    /// The tvOS video card context menu: mark watched / unwatched and
    /// delete from the server. Shared by the home rows, the filtered list
    /// and search results so all three offer the same actions.
    func tvVideoContextMenu(
        video: VideoResponse,
        onMarkWatched: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        contextMenu {
            Button(action: onMarkWatched) {
                Label(
                    video.isWatched
                        ? String.localised("video.markAsUnwatched", table: .videos)
                        : String.localised("video.markAsWatched", table: .videos),
                    systemImage: video.isWatched ? "eye.slash" : "eye"
                )
            }
            Button(role: .destructive, action: onDelete) {
                Label(
                    String.localised("video.deleteFromServer", table: .videos),
                    systemImage: "trash"
                )
            }
        }
    }
}
#endif
