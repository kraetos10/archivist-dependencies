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

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ChannelDetailHeader(store: store)

                Section {
                    ChannelVideosCarousel(store: store)
                } header: {
                    ChannelVideosSectionHeader(store: store)
                }

                if !store.pendingDownloads.isEmpty || store.isLoadingDownloads {
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

            Button(role: .destructive) {
                send(.unsubscribeTapped)
            } label: {
                Label(String.localised("generic.unsubscribe", table: .generic), systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.semibold))
        }
        .accessibilityLabel(String.localised("generic.actions", table: .generic))
    }
}
#endif
