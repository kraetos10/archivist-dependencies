#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomePlaylistsRow: View {
    static let maxItems = 10

    let playlists: [PlaylistResponse]
    let serverConfig: ServerConfig
    let onPlaylistTapped: (PlaylistResponse) -> Void
    let onViewAll: () -> Void

    var body: some View {
        TVHomeSectionContainer(
            title: String(localized: "Playlists"),
            icon: "music.note.list",
            onViewAll: onViewAll
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(playlists.prefix(Self.maxItems)) { playlist in
                        TVPlaylistCardView(
                            playlist: playlist,
                            serverConfig: serverConfig
                        ) {
                            onPlaylistTapped(playlist)
                        }
                        .frame(width: 400)
                    }

                    if playlists.count > 0 {
                        TVHomeViewAllCard(action: onViewAll)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
    }
}

#endif
