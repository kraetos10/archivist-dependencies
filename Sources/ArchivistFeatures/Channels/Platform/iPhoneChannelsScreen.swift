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
                .navigationTitle(String.localised("generic.channels", table: .generic))
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
            newContentFilterRow
                .padding(.horizontal)
                .padding(.top, 8)

            if store.hasLoaded && store.filteredChannels.isEmpty && store.showNewOnly {
                EmptyStateView(
                    icon: "sparkles",
                    title: String.localised("generic.noNewVideos", table: .generic),
                    description: String.localised("generic.noNewVideosDescription", table: .generic)
                )
            } else if store.hasLoaded && store.filteredChannels.isEmpty && store.searchQuery.isEmpty {
                EmptyStateView(
                    icon: "person.2.rectangle.stack",
                    title: String.localised("login.noChannels", table: .login),
                    description: String.localised("login.subscribeChannelsDescription", table: .login)
                )
            } else if store.hasLoaded && store.filteredChannels.isEmpty && !store.searchQuery.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String.localised("video.empty.noSearchResults", table: .videos),
                    description: String.localised("video.empty.tryDifferentSearch", table: .videos)
                )
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
                                serverConfig: store.serverConfig,
                                hasNewContent: store.channelIdsWithNewContent.contains(channel.channelId)
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    send(.unsubscribeTapped(channel))
                                } label: {
                                    Label(
                                        String.localised("generic.unsubscribe", table: .generic),
                                        systemImage: "xmark.circle"
                                    )
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
        .refreshable { send(.pullToRefreshTriggered) }
        .safeAreaInset(edge: .bottom) {
            FloatingAddButton { send(.addChannelTapped) }
        }
        .sheet(item: $store.scope(state: \.addChannel, action: \.addChannel)) { addChannelStore in
            AddChannelScreen(store: addChannelStore)
                .presentationDetents([.medium])
        }
    }
    private var newContentFilterRow: some View {
        HStack(spacing: 8) {
            filterPill(
                label: String.localised("generic.all", table: .generic),
                icon: "line.3.horizontal.decrease.circle",
                isSelected: !store.showNewOnly,
                showNewOnly: false
            )

            filterPill(
                label: String.localised("generic.newVideos", table: .generic),
                icon: "sparkles",
                isSelected: store.showNewOnly,
                showNewOnly: true
            )

            Spacer()
        }
    }

    private func filterPill(
        label: String,
        icon: String,
        isSelected: Bool,
        showNewOnly: Bool
    ) -> some View {
        Button {
            send(.newFilterToggled(showNewOnly), animation: .default)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(isSelected ? Color.Brand.primary : Color.Text.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isSelected ? Color.Text.primary : Color.Surface.highlight)
            .clipShape(Capsule())
        }
    }
}

#endif
