import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Banner, title, owning channel, entry count and description.
struct PlaylistDetailHeader: View {
    let store: StoreOf<PlaylistDetailReducer>

    var body: some View {
        VStack(spacing: 12) {
            StretchyBannerView(url: store.playlistThumbURL)

            Text(store.playlist.playlistName)
                .font(.title2)
                .bold()
                .foregroundStyle(Color.Text.primary)

            if let channel = store.playlist.playlistChannel {
                Text(channel)
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
            }

            Text(String.localised("playlist.entryCount \(store.playlist.entryCount)", table: .videos))
                .font(.caption)
                .foregroundStyle(Color.Brand.secondary)

            if let description = store.displayDescription {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
    }
}
