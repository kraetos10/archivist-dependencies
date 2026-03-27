#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelsReducer.self)
public struct iPhoneChannelsScreen: View {
    @Bindable public var store: StoreOf<ChannelsReducer>

    public init(store: StoreOf<ChannelsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            channelListContent
                .navigationTitle(String.localised("generic.channels"))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $store.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: String.localised("login.searchChannels", table: .login)
                )
        } destination: { store in
            switch store.case {
            case .channelDetail(let detailStore):
                ChannelDetailScreen(store: detailStore)
            }
        }

        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

    // MARK: - Shared Views

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
        }
        .sheet(item: $store.scope(state: \.addChannel, action: \.addChannel)) { addChannelStore in
            AddChannelScreen(store: addChannelStore)
                .presentationDetents([.medium])
        }
    }
}

#endif
