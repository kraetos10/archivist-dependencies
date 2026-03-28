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
            playlistListContent
                .navigationTitle(String.localised("generic.playlists", table: .generic))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $store.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: String.localised("login.searchPlaylists", table: .login)
                )
                .background(Color.Brand.primary)
                .onAppear {
                    send(.splitViewEnabled)
                    send(.viewDidAppear)
                }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            if let detailStore = store.scope(state: \.selectedPlaylist, action: \.playlistDetail.presented) {
                PlaylistDetailScreen(store: detailStore)
                    .id(store.selectedPlaylist?.playlist.playlistId)
            } else {
                emptyDetailView
            }
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

    // MARK: - Empty Detail

    private var emptyDetailView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(Color.Brand.secondary)
            Text(String(localized: "Select a playlist"))
                .font(.headline)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Brand.primary)
    }

    // MARK: - List Content

    private var playlistListContent: some View {
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
                            let isSelected = store.selectedPlaylist?.playlist.playlistId == playlist.playlistId
                            PlaylistCardView(
                                playlist: playlist,
                                serverConfig: store.serverConfig
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.Accent.dark, lineWidth: isSelected ? 2.5 : 0)
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
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                FloatingAddButton(action: { send(.addPlaylistTapped) })
                    .button
                    .popover(item: $store.scope(state: \.addPlaylist, action: \.addPlaylist)) { addPlaylistStore in
                        AddPlaylistScreen(store: addPlaylistStore)
                            .frame(width: 400)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 8)
            }
        }
    }
}
#endif
