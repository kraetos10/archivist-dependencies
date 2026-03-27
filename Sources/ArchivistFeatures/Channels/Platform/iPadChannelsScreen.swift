#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelsReducer.self)
public struct iPadChannelsScreen: View {
    @Bindable public var store: StoreOf<ChannelsReducer>

    public init(store: StoreOf<ChannelsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 16)]

    public var body: some View {
        NavigationStack {
            channelListContent
                .navigationTitle(String.localised("generic.channels"))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $store.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: String.localised("login.searchChannels", table: .login)
                )
                .toolbarBackground(Color.Brand.primary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .background(Color.Brand.primary)
                .onAppear {
                    store.useSplitView = true
                    send(.viewDidAppear)
                }
                .alert($store.scope(state: \.alert, action: \.alert))
                .navigationDestination(item: $store.scope(state: \.selectedChannel, action: \.channelDetail)) { detailStore in
                    ChannelDetailScreen(store: detailStore)
                }
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

    // MARK: - List Content

    private var channelListContent: some View {
        ScrollView {
            if store.hasLoaded && store.filteredChannels.isEmpty && store.searchQuery.isEmpty {
                EmptyStateView(icon: "person.2.rectangle.stack", title: String.localised("login.noChannels", table: .login), description: String.localised("login.subscribeChannelsDescription", table: .login))
            } else if store.hasLoaded && store.filteredChannels.isEmpty && !store.searchQuery.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: String.localised("video.empty.noSearchResults", table: .videos), description: String.localised("video.empty.tryDifferentSearch", table: .videos))
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    if store.isLoading && store.filteredChannels.isEmpty {
                        ForEach(ChannelResponse.placeholders) { channel in
                            ChannelCardView(
                                channel: channel,
                                serverConfig: store.serverConfig
                            )
                            .redacted(reason: .placeholder)
                        }
                    } else {
                        ForEach(store.filteredChannels) { channel in
                            ChannelCardView(
                                channel: channel,
                                serverConfig: store.serverConfig
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    send(.unsubscribeTapped(channel))
                                } label: {
                                    Label(String.localised("generic.unsubscribe"), systemImage: "xmark.circle")
                                }
                            }
                            .pressable {
                                send(.channelTapped(channel))
                            }
                            .onAppear {
                                if channel.id == store.filteredChannels.last?.id {
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
            FloatingAddButton { send(.addChannelTapped) }
                .popover(item: $store.scope(state: \.addChannel, action: \.addChannel)) { addChannelStore in
                    AddChannelScreen(store: addChannelStore)
                        .frame(width: 400)
                }
        }
    }
}
#endif
