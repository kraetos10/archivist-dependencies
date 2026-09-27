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

                Section {
                    ChannelVideosCarousel(store: store)
                } header: {
                    ChannelVideosSectionHeader(store: store)
                }

                if store.showsPendingDownloads {
                    Section {
                        ChannelPendingDownloadsList(store: store)
                    } header: {
                        ChannelDownloadsSectionHeader(store: store)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.Brand.primary)
        .refreshable { send(.pullToRefreshTriggered) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                channelMenu
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

    private var channelMenu: some View {
        Menu {
            if let url = store.channel.youtubeURL {
                ShareLink(item: url) {
                    Label(
                        String.localised("generic.share", table: .generic),
                        systemImage: "square.and.arrow.up"
                    )
                }
            }

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
