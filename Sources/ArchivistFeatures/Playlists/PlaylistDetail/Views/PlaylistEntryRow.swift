import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// One playlist entry. Entries the server hasn't downloaded yet are dimmed
/// and carry a download affordance — tapping one queues it rather than
/// playing it.
struct PlaylistEntryRow: View {
    let entry: PlaylistEntry
    let thumbnailURL: URL?
    let isAvailable: Bool

    var body: some View {
        HStack {
            VideoRowView(
                title: entry.title ?? "",
                subtitle: entry.uploader,
                thumbnailURL: thumbnailURL
            )

            if !isAvailable {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(Color.Accent.dark)
                    .padding(.trailing, 16)
                    .accessibilityLabel(
                        String.localised("video.downloadToDevice", table: .videos)
                    )
            }
        }
        .opacity(isAvailable ? 1 : 0.6)
    }
}
