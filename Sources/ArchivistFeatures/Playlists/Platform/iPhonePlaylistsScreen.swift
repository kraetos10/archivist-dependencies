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
            ScrollView {
                if store.hasLoaded && store.filteredPlaylists.isEmpty && store.searchQuery.isEmpty {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: String.localised("login.noPlaylists", table: .login),
                        description: String.localised("login.subscribePlaylistsDescription", table: .login)
                    )
                } else if store.hasLoaded && store.filteredPlaylists.isEmpty && !store.searchQuery.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: String.localised("video.empty.noSearchResults", table: .videos),
                        description: String.localised("video.empty.tryDifferentSearch", table: .videos)
                    )
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
            .refreshable { send(.pullToRefreshTriggered) }
            .navigationTitle(String.localised("generic.playlists", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String.localised("login.searchPlaylists", table: .login)
            )
            .safeAreaInset(edge: .bottom) {
                FloatingAddButton { send(.addPlaylistTapped) }
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
