#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The scrolling playlist grid shared by the iPhone and iPad screens: empty
/// and placeholder states plus the cards.
@ViewAction(for: PlaylistsReducer.self)
struct PlaylistsGridContent: View {
    let store: StoreOf<PlaylistsReducer>
    let columns: [GridItem]
    /// iPad split view outlines the playlist shown in the detail column.
    let highlightsSelection: Bool

    var body: some View {
        // Read once per pass: `content` merges the search results with a
        // locale-aware filter over every playlist.
        let content = store.content
        let selectedId = highlightsSelection ? store.selectedPlaylist?.playlist.playlistId : nil

        ScrollView {
            switch content {
            case .noPlaylists:
                EmptyStateView(
                    icon: "music.note.list",
                    title: String.localised("login.noPlaylists", table: .login),
                    description: String.localised("login.subscribePlaylistsDescription", table: .login)
                )
            case .noSearchResults:
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String.localised("video.empty.noSearchResults", table: .videos),
                    description: String.localised("video.empty.tryDifferentSearch", table: .videos)
                )
            case .placeholders:
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(PlaylistResponse.placeholders) { playlist in
                        PlaylistCardView(
                            playlist: playlist,
                            serverConfig: store.serverConfig
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding()
            case .playlists(let playlists):
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(playlists) { playlist in
                        let isSelected = playlist.playlistId == selectedId
                        PlaylistCardView(
                            playlist: playlist,
                            serverConfig: store.serverConfig
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.Accent.dark, lineWidth: isSelected ? 2.5 : 0)
                        }
                        .pressable {
                            send(.playlistCardTapped(playlist))
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .onAppear {
                            // Anchor on the list actually shown: while
                            // searching, the page buffer's last item isn't
                            // rendered, so paging would never fire.
                            if playlist.id == playlists.last?.id {
                                send(.lastItemAppeared)
                            }
                        }
                    }
                }
                .padding()

                if store.isLoadingMore {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .padding()
                }
            }
        }
        .background(Color.Brand.primary)
        .refreshable { send(.pullToRefreshTriggered) }
    }
}
#endif
