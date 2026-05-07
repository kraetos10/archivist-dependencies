#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelsReducer.self)
public struct TVChannelsScreen: View {
    @Bindable public var store: StoreOf<ChannelsReducer>

    public init(store: StoreOf<ChannelsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 48)]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                // Segmented filter picker
                Picker("", selection: $store.filter.animation()) {
                    Text(String.localised("generic.all", table: .generic))
                        .tag(ChannelListFilter.all)
                    Text(String.localised("generic.unwatched", table: .generic))
                        .tag(ChannelListFilter.withUnwatched)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 48)
                .padding(.top, 24)

                if store.hasLoaded && store.filteredChannels.isEmpty && store.filter == .withUnwatched {
                    emptyUnwatchedView
                } else if store.hasLoaded && store.filteredChannels.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 48) {
                        if store.isLoading && store.filteredChannels.isEmpty {
                            ForEach(ChannelResponse.placeholders) { channel in
                                TVChannelCardView(
                                    channel: channel,
                                    serverConfig: store.serverConfig
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.filteredChannels) { channel in
                                TVChannelCardView(
                                    channel: channel,
                                    serverConfig: store.serverConfig
                                ) {
                                    send(.channelTapped(channel))
                                }
                                // Paginate on the unfiltered list so additional
                                // pages are fetched regardless of the active filter.
                                .onAppear {
                                    if channel.id == store.channels.last?.id {
                                        send(.lastItemAppeared)
                                    }
                                }
                            }
                        }
                    }
                    .padding(48)

                    if store.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .navigationTitle("")
        } destination: { store in
            switch store.case {
            case .channelDetail(let detailStore):
                TVChannelDetailScreen(store: detailStore)
            }
        }
        .onAppear { send(.viewDidAppear) }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                TVVideoDetailScreen(store: detailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
    }

    // MARK: - Empty states

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 120)
            Image(systemName: "person.2.rectangle.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String.localised("login.noChannels", table: .login))
                .font(.title2)
            Text(String.localised("login.subscribeChannelsDescription", table: .login))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyUnwatchedView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 120)
            Image(systemName: "eye.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String.localised("video.empty.noUnwatched", table: .videos))
                .font(.title2)
            Text(String.localised("generic.noNewVideosDescription", table: .generic))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif