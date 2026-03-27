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
        NavigationStack {
            playlistListContent
                .navigationTitle(String.localised("generic.playlists"))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $store.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: String.localised("login.searchPlaylists", table: .login)
                )
                .toolbarBackground(Color.Brand.primary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .background(Color.Brand.primary)
                .onAppear {
                    store.useSplitView = true
                    send(.viewDidAppear)
                }
                .navigationDestination(item: $store.scope(state: \.selectedPlaylist, action: \.playlistDetail)) { detailStore in
                    PlaylistDetailScreen(store: detailStore)
                }
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

    // MARK: - List Content

    private var playlistListContent: some View {
        ScrollView {
            if store.hasLoaded && store.filteredPlaylists.isEmpty && store.searchQuery.isEmpty {
                EmptyStateView(icon: "music.note.list", title: String.localised("login.noPlaylists", table: .login), description: String.localised("login.subscribePlaylistsDescription", table: .login))
            } else if store.hasLoaded && store.filteredPlaylists.isEmpty && !store.searchQuery.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: String.localised("video.empty.noSearchResults", table: .videos), description: String.localised("video.empty.tryDifferentSearch", table: .videos))
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    if store.isLoading && store.playlists.isEmpty {
                        ForEach(PlaylistResponse.placeholders) { playlist in
                            PlaylistCardView(
                                playlist: playlist,
                                serverConfig: store.serverConfig
                            )
                            .redacted(reason: .placeholder)
                        }
                    } else {
                        ForEach(store.filteredPlaylists) { playlist in
                            PlaylistCardView(
                                playlist: playlist,
                                serverConfig: store.serverConfig
                            )
                            .pressable {
                                send(.playlistCardTapped(playlist))
                            }
                            .onAppear {
                                if playlist.id == store.playlists.last?.id {
                                    send(.lastItemAppeared)
                                }
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
        .refreshable { await send(.pullToRefreshTriggered).finish() }
        .safeAreaInset(edge: .bottom) {
            FloatingAddButton { send(.addPlaylistTapped) }
                .popover(item: $store.scope(state: \.addPlaylist, action: \.addPlaylist)) { addPlaylistStore in
                    AddPlaylistScreen(store: addPlaylistStore)
                        .frame(width: 400)
                }
        }
    }
}
#endif
