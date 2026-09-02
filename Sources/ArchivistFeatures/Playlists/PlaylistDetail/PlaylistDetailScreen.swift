import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaylistDetailReducer.self)
public struct PlaylistDetailScreen: View {
    @Bindable public var store: StoreOf<PlaylistDetailReducer>

    public init(store: StoreOf<PlaylistDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                PlaylistDetailHeader(store: store)

                Section {
                    PlaylistEntriesList(store: store)
                } header: {
                    PinnedSectionHeader(title: String.localised("generic.videos", table: .generic))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.Brand.primary)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            if store.isCustomPlaylist {
                FloatingAddButton { send(.addVideoTapped) }
            }
        }
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .topBarTrailing) {
                loopButton
            }

            ToolbarItem(placement: .topBarTrailing) {
                playlistMenu
            }
            #endif
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        #if !os(tvOS)
        .sheet(item: $store.scope(state: \.videoPicker, action: \.videoPicker)) { pickerStore in
            VideoPickerScreen(store: pickerStore)
        }
        #endif
        .onAppear { send(.viewDidAppear) }
        .onChange(of: store.playlist.playlistId) {
            send(.viewDidAppear)
        }
    }

    #if !os(tvOS)
    private var loopButton: some View {
        Button {
            send(.loopToggled)
        } label: {
            Image(systemName: "repeat")
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    store.loopPlaylistEnabled
                        ? Color.Accent.dark
                        : Color.Brand.secondary
                )
        }
        .accessibilityLabel(String.localised("video.loopPlaylist", table: .videos))
        .accessibilityAddTraits(store.loopPlaylistEnabled ? .isSelected : [])
    }

    private var playlistMenu: some View {
        Menu {
            if !store.isCustomPlaylist, let youtubeURL = store.playlist.youtubeURL {
                ShareLink(item: youtubeURL) {
                    Label(
                        String.localised("generic.share", table: .generic),
                        systemImage: "square.and.arrow.up"
                    )
                }
            }

            Button(role: .destructive) {
                send(.unsubscribeTapped)
            } label: {
                Label(
                    store.isCustomPlaylist
                        ? String.localised("generic.delete", table: .generic)
                        : String.localised("video.removePlaylist", table: .videos),
                    systemImage: "trash"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.semibold))
        }
        .accessibilityLabel(String.localised("generic.actions", table: .generic))
    }
    #endif
}
