#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: PlaylistPickerReducer.self)
public struct PlaylistPickerScreen: View {
    @Bindable public var store: StoreOf<PlaylistPickerReducer>

    public init(store: StoreOf<PlaylistPickerReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    List {
                        ForEach(PlaylistResponse.placeholders.prefix(4)) { playlist in
                            PlaylistPickerRow(playlist: playlist, alreadyAdded: false)
                                .redacted(reason: .placeholder)
                        }
                        .listRowBackground(Color.Surface.highlight)
                    }
                } else if store.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .scaledSystemFont(size: 48, relativeTo: .largeTitle)
                            // Decorative: the adjacent label carries the meaning.
                            .accessibilityHidden(true)
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
                            let alreadyAdded = store.state.isAlreadyAdded(playlist)
                            Button {
                                send(.playlistTapped(playlist))
                            } label: {
                                PlaylistPickerRow(playlist: playlist, alreadyAdded: alreadyAdded)
                            }
                            .disabled(store.isAdding || alreadyAdded)
                            .listRowBackground(Color.Surface.highlight)
                            .onAppear {
                                if playlist.id == store.playlists.last?.id {
                                    send(.lastItemAppeared)
                                }
                            }
                        }

                        if store.isLoadingMore {
                            ProgressView()
                                .tint(Color.Progress.tint)
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
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
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

/// A playlist in the picker: name, entry count, and whether the video is
/// already in it.
private struct PlaylistPickerRow: View {
    let playlist: PlaylistResponse
    let alreadyAdded: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.playlistName)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                Text(String.localised("playlist.entryCount \(playlist.entryCount)", table: .videos))
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
            }
            Spacer()
            Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                .foregroundStyle(Color.Accent.dark)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            alreadyAdded
                ? String.localised("playlist.alreadyAdded", table: .videos)
                : ""
        )
    }
}
#endif
