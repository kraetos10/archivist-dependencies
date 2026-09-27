#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaylistsReducer.self)
public struct iPadPlaylistsScreen: View {
    @Bindable public var store: StoreOf<PlaylistsReducer>

    public init(store: StoreOf<PlaylistsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 16)]

    public var body: some View {
        NavigationSplitView {
            PlaylistsGridContent(
                store: store,
                columns: columns,
                highlightsSelection: true
            )
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    FloatingAddButton(
                        accessibilityLabel: String.localised("login.addPlaylist", table: .login)
                    ) {
                        send(.addPlaylistTapped)
                    }
                    .button
                    .popover(item: $store.scope(state: \.addPlaylist, action: \.addPlaylist)) { addPlaylistStore in
                        AddPlaylistScreen(store: addPlaylistStore)
                            .frame(width: 400)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(String.localised("generic.playlists", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String.localised("login.searchPlaylists", table: .login)
            )
            .background(Color.Brand.primary)
            .onAppear { send(.splitViewDidAppear) }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            if let detailStore = store.scope(state: \.selectedPlaylist, action: \.playlistDetail.presented) {
                PlaylistDetailScreen(store: detailStore)
                    .id(store.selectedPlaylist?.playlist.playlistId)
            } else {
                PlaylistsEmptyDetailView()
            }
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }
}

/// The split view's detail column before any playlist is picked.
private struct PlaylistsEmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .scaledSystemFont(size: 48, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(Color.Brand.secondary)
            Text(String.localised("playlist.selectPrompt", table: .login))
                .font(.headline)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Brand.primary)
    }
}
#endif
