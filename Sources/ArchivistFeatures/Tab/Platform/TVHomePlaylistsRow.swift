#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomePlaylistsRow: View {
    let playlists: [PlaylistResponse]
    let serverConfig: ServerConfig
    let focus: FocusState<TVHomeFocus?>.Binding
    let onPlaylistTapped: (PlaylistResponse) -> Void
    let onViewAll: () -> Void

    var body: some View {
        TVHomeSectionContainer(
            title: String.localised("generic.playlists", table: .generic),
            icon: "music.note.list"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                    ForEach(playlists) { playlist in
                        TVPlaylistCardView(
                            playlist: playlist,
                            serverConfig: serverConfig
                        ) {
                            onPlaylistTapped(playlist)
                        }
                        .frame(width: TVLayout.cardWidth)
                        .focused(focus, equals: .card(.playlists, id: playlist.playlistId))
                    }

                    if !playlists.isEmpty {
                        TVHomeViewAllCard(action: onViewAll)
                            .focused(focus, equals: .viewAll(.playlists))
                    }
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .scrollClipDisabled()
        }
    }
}
#endif
