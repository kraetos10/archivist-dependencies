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
                if store.hasLoaded && store.channels.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 48) {
                        if store.isLoading && store.channels.isEmpty {
                            ForEach(ChannelResponse.placeholders) { channel in
                                TVChannelCardView(
                                    channel: channel,
                                    serverConfig: store.serverConfig
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.channels) { channel in
                                TVChannelCardView(
                                    channel: channel,
                                    serverConfig: store.serverConfig
                                ) {
                                    send(.channelTapped(channel))
                                }
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

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 120)
            Image(systemName: "person.2.rectangle.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String(localized: "No channels yet"))
                .font(.title2)
            Text(String(localized: "Subscribe to channels to see them here."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
