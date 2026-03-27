#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaylistsReducer.self)
public struct TVPlaylistsScreen: View {
    @Bindable public var store: StoreOf<PlaylistsReducer>

    public init(store: StoreOf<PlaylistsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 48)]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                if store.hasLoaded && store.playlists.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 48) {
                        if store.isLoading && store.playlists.isEmpty {
                            ForEach(PlaylistResponse.placeholders) { playlist in
                                TVPlaylistCardView(
                                    playlist: playlist,
                                    serverConfig: store.serverConfig
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.playlists) { playlist in
                                TVPlaylistCardView(
                                    playlist: playlist,
                                    serverConfig: store.serverConfig
                                ) {
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
                    .padding(48)

                    if store.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .navigationTitle("")
        } destination: { store in
            switch store.case {
            case .playlistDetail(let detailStore):
                TVPlaylistDetailScreen(store: detailStore)
            }
        }
        .onAppear { send(.viewDidAppear) }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                TVVideoDetailScreen(store: detailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 120)
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String.localised("login.noPlaylists", table: .login))
                .font(.title2)
            Text(String.localised("login.subscribePlaylistsDescription", table: .login))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
