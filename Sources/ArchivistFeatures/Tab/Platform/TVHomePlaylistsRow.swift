#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomePlaylistsRow: View {
    let playlists: [PlaylistResponse]
    let serverConfig: ServerConfig
    let onPlaylistTapped: (PlaylistResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Playlists"))
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(playlists) { playlist in
                        TVPlaylistCardView(
                            playlist: playlist,
                            serverConfig: serverConfig
                        ) {
                            onPlaylistTapped(playlist)
                        }
                        .frame(width: 400)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

#endif
