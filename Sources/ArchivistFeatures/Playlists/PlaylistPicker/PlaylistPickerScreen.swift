#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: PlaylistPickerReducer.self)
public struct PlaylistPickerScreen: View {
    public let store: StoreOf<PlaylistPickerReducer>

    public init(store: StoreOf<PlaylistPickerReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    List {
                        ForEach(PlaylistResponse.placeholders.prefix(4)) { playlist in
                            playlistRow(playlist, alreadyAdded: false)
                                .redacted(reason: .placeholder)
                        }
                        .listRowBackground(Color.Surface.highlight)
                    }
                } else if store.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.Brand.secondary)
                        Text(String.localised("login.noCustomPlaylists", table: .login))
                            .font(.headline)
                            .foregroundStyle(Color.Text.primary)
                        Text(String.localised("login.createPlaylistDescription", table: .login))
                            .font(.subheadline)
                            .foregroundStyle(Color.Brand.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(store.playlists) { playlist in
                            let alreadyAdded = store.alreadyInPlaylistIds.contains(playlist.playlistId)
                            Button {
                                send(.playlistTapped(playlist))
                            } label: {
                                playlistRow(playlist, alreadyAdded: alreadyAdded)
                            }
                            .disabled(store.isAdding || alreadyAdded)
                            .listRowBackground(Color.Surface.highlight)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("video.addToPlaylist", table: .videos))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { send(.viewDidAppear) }
    }

    private func playlistRow(_ playlist: PlaylistResponse, alreadyAdded: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.playlistName)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                Text("\(playlist.entryCount) videos")
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
            }
            Spacer()
            if alreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.Accent.dark)
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.Accent.dark)
            }
        }
    }
}
#endif
