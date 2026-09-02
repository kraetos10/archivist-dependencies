import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Banner, title, owning channel, entry count and description.
struct PlaylistDetailHeader: View {
    let store: StoreOf<PlaylistDetailReducer>

    /// The API returns the string "false" for playlists with no description
    /// rather than omitting the field, so it has to be filtered out here.
    private var description: String? {
        guard let description = store.playlist.playlistDescription,
              !description.isEmpty,
              description.lowercased() != "false"
        else { return nil }
        return description
    }

    var body: some View {
        VStack(spacing: 12) {
            StretchyBannerView(url: store.playlistThumbURL)

            Text(store.playlist.playlistName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)

            if let channel = store.playlist.playlistChannel {
                Text(channel)
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
            }

            Text("\(store.playlist.entryCount) videos")
                .font(.caption)
                .foregroundStyle(Color.Brand.secondary)

            if let description {
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
