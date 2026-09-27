#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaylistsReducer.self)
public struct iPhonePlaylistsScreen: View {
    @Bindable public var store: StoreOf<PlaylistsReducer>

    public init(store: StoreOf<PlaylistsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            PlaylistsGridContent(
                store: store,
                columns: columns,
                highlightsSelection: false
            )
            .navigationTitle(String.localised("generic.playlists", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String.localised("login.searchPlaylists", table: .login)
            )
            .safeAreaInset(edge: .bottom) {
                FloatingAddButton(
                    accessibilityLabel: String.localised("login.addPlaylist", table: .login)
                ) {
                    send(.addPlaylistTapped)
                }
            }
            .sheet(item: $store.scope(state: \.addPlaylist, action: \.addPlaylist)) { addPlaylistStore in
                AddPlaylistScreen(store: addPlaylistStore)
            }
        } destination: { store in
            switch store.case {
            case .playlistDetail(let detailStore):
                PlaylistDetailScreen(store: detailStore)
            }
        }
        .onAppear { send(.viewDidAppear) }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }
}
#endif
