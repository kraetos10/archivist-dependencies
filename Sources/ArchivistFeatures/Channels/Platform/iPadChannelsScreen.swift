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

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 16)]

    public var body: some View {
        NavigationSplitView {
            channelListContent
                .navigationTitle(String.localised("generic.channels", table: .generic))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $store.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: String.localised("login.searchChannels", table: .login)
                )
                .background(Color.Brand.primary)
                .onAppear {
                    send(.splitViewEnabled)
                    send(.viewDidAppear)
                }
                .alert($store.scope(state: \.alert, action: \.alert))
            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
        } detail: {
            if let detailStore = store.scope(state: \.selectedChannel, action: \.channelDetail.presented) {
                ChannelDetailScreen(store: detailStore)
            } else {
                emptyDetailView
            }
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

    // MARK: - Empty Detail

    private var emptyDetailView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(Color.Brand.secondary)
            Text(String(localized: "Select a channel"))
                .font(.headline)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Brand.primary)
    }

    // MARK: - List Content

    private var channelListContent: some View {
        ScrollView {
            filterRow
                .padding(.horizontal)
                .padding(.top, 8)

            if store.hasLoaded && store.filteredChannels.isEmpty && store.filter == .withNew {
                EmptyStateView(
                    icon: "sparkles",
                    title: String.localised("generic.noNewVideos", table: .generic),
                    description: String.localised("generic.noNewVideosDescription", table: .generic)
                )
            } else if store.hasLoaded && store.filteredChannels.isEmpty && store.filter == .withUnwatched {
                EmptyStateView(
                    icon: "eye.slash",
                    title: String.localised("video.empty.noUnwatched", table: .videos),
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
                            let isSelected = store.selectedChannel?.channel.channelId == channel.channelId
                            ChannelCardView(
                                channel: channel,
                                serverConfig: store.serverConfig,
                                hasNewContent: store.channelIdsWithNewContent.contains(channel.channelId)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.Accent.dark, lineWidth: isSelected ? 2.5 : 0)
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
            HStack {
                Spacer()
                FloatingAddButton(action: { send(.addChannelTapped) })
                    .button
                    .popover(item: $store.scope(state: \.addChannel, action: \.addChannel)) { addChannelStore in
                        AddChannelScreen(store: addChannelStore)
                            .frame(width: 400)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 8)
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(
                    label: String.localised("generic.all", table: .generic),
                    icon: "line.3.horizontal.decrease.circle",
                    filter: .all
                )

                filterPill(
                    label: String.localised("generic.newVideos", table: .generic),
                    icon: "sparkles",
                    filter: .withNew
                )

                filterPill(
                    label: String.localised("generic.unwatched", table: .generic),
                    icon: "eye.slash",
                    filter: .withUnwatched
                )
            }
        }
    }

    private func filterPill(
        label: String,
        icon: String,
        filter: ChannelListFilter
    ) -> some View {
        let isSelected = store.filter == filter
        return Button {
            send(.filterChanged(filter), animation: .default)
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
