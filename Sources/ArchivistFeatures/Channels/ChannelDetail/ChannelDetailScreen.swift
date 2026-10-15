#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelDetailReducer.self)
public struct ChannelDetailScreen: View {
    @Bindable public var store: StoreOf<ChannelDetailReducer>

    public init(store: StoreOf<ChannelDetailReducer>) {
        self.store = store
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ChannelDetailHeader(store: store)

                if store.showsPendingDownloads {
                    ChannelPendingDownloadsList(store: store)
                }

                Section {
                    ChannelVideosGrid(store: store)
                } header: {
                    ChannelVideosSectionHeader(store: store)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.Brand.primary)
        .refreshable { send(.pullToRefreshTriggered) }
        .navigationBarBackButtonHidden(store.isSelecting)
        .toolbar(store.isSelecting ? .hidden : .automatic, for: .tabBar)
        .toolbar {
            if store.isSelecting {
                selectionToolbar
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    channelMenu
                }
            }
        }
        .onAppear { send(.viewDidAppear) }
        .onChange(of: store.channel.channelId) {
            send(.viewDidAppear)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .modifier(ChannelDownloadDetailSheet(store: store, sizeClass: horizontalSizeClass))
        .sheet(item: $store.scope(state: \.playlistPicker, action: \.playlistPicker)) { pickerStore in
            PlaylistPickerScreen(store: pickerStore)
        }
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(
                store.areAllVideosSelected
                    ? String.localised("generic.deselectAll", table: .generic)
                    : String.localised("generic.selectAll", table: .generic)
            ) {
                send(.selectAllTapped, animation: .default)
            }
        }
        ToolbarItem(placement: .principal) {
            Text(store.selectionTitle)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(String.localised("generic.done", table: .generic)) {
                send(.doneSelectingTapped, animation: .default)
            }
            .fontWeight(.semibold)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button(
                store.selectionMarksWatched
                    ? String.localised("video.markAsWatched", table: .videos)
                    : String.localised("video.markAsUnwatched", table: .videos),
                systemImage: store.selectionMarksWatched ? "eye" : "eye.slash"
            ) {
                send(.markSelectedWatchedTapped, animation: .default)
            }
            .disabled(store.selectedVideos.isEmpty)

            Spacer()

            Button(
                String.localised("video.downloadToDevice", table: .videos),
                systemImage: "arrow.down.circle"
            ) {
                send(.downloadSelectedToDeviceTapped, animation: .default)
            }
            .disabled(store.selectedVideos.isEmpty)

            Spacer()

            Button(
                String.localised("video.deleteFromServer", table: .videos),
                systemImage: "trash",
                role: .destructive
            ) {
                send(.deleteSelectedTapped)
            }
            .disabled(store.selectedVideos.isEmpty)
        }
    }

    private var channelMenu: some View {
        Menu {
            Button(
                String.localised("generic.select", table: .generic),
                systemImage: "checkmark.circle"
            ) {
                send(.selectTapped, animation: .default)
            }
            .disabled(store.filteredVideos.isEmpty)

            if let url = store.channel.youtubeURL {
                ShareLink(item: url) {
                    Label(
                        String.localised("generic.share", table: .generic),
                        systemImage: "square.and.arrow.up"
                    )
                }
            }

            Divider()

            Button(
                String.localised("video.clearFiltered.action", table: .videos),
                systemImage: "trash",
                role: .destructive
            ) {
                send(.clearFilteredTapped)
            }
            .disabled(store.filteredVideos.isEmpty)

            Button(
                String.localised("generic.unsubscribe", table: .generic),
                systemImage: "xmark.circle",
                role: .destructive
            ) {
                send(.unsubscribeTapped)
            }
        } label: {
            Label(String.localised("generic.actions", table: .generic), systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
        }
    }
}
#endif
