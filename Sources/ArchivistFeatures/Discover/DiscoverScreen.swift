#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DiscoverReducer.self)
public struct DiscoverScreen: View {
    @Bindable public var store: StoreOf<DiscoverReducer>

    public init(store: StoreOf<DiscoverReducer>) {
        self.store = store
    }

    private let videoColumns = [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)]
    private let channelColumns = [GridItem(.adaptive(minimum: 340), spacing: 12)]

    public var body: some View {
        NavigationStack {
            Group {
                if store.needsSetup {
                    setupPrompt
                } else {
                    feed
                }
            }
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("discover.title", table: .discover))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String.localised("discover.search.prompt", table: .discover)
            )
            .onSubmit(of: .search) { send(.searchSubmitted) }
            .toolbar {
                if !store.needsSetup {
                    ToolbarItem(placement: .topBarTrailing) {
                        optionsMenu
                    }
                }
            }
            .navigationDestination(item: $store.browsedChannel) { _ in
                DiscoverChannelScreen(store: store)
            }
        }
        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.setup, action: \.setup)) { setupStore in
            DiscoverSetupScreen(store: setupStore)
        }
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Picker(
                    String.localised("discover.title", table: .discover),
                    selection: $store.searchScope
                ) {
                    Text(String.localised("discover.scope.videos", table: .discover))
                        .tag(DiscoverReducer.State.SearchScope.videos)
                    Text(String.localised("discover.scope.channels", table: .discover))
                        .tag(DiscoverReducer.State.SearchScope.channels)
                }
                .pickerStyle(.segmented)

                if store.isQuotaExceeded {
                    DiscoverNotice(
                        icon: "hourglass",
                        title: String.localised("discover.quota.title", table: .discover),
                        message: String.localised("discover.quota.message", table: .discover),
                        retryTitle: nil,
                        onRetry: {}
                    )
                }

                if let message = store.errorMessage {
                    DiscoverNotice(
                        icon: "wifi.exclamationmark",
                        title: String.localised("discover.error.title", table: .discover),
                        message: message,
                        retryTitle: String.localised("discover.error.retry", table: .discover),
                        onRetry: { send(.retryTapped) }
                    )
                }

                results
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var results: some View {
        if store.showsChannelPrompt {
            EmptyStateView(
                icon: "person.2.wave.2",
                title: String.localised("discover.empty.channels.title", table: .discover),
                description: String.localised("discover.empty.channels.description", table: .discover)
            )
        } else if store.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if store.showsNoResults {
            EmptyStateView(
                icon: "magnifyingglass",
                title: String.localised("discover.empty.noResults.title", table: .discover),
                description: String.localised("discover.empty.noResults.description", table: .discover)
            )
        } else if store.searchScope == .videos {
            videoResults
        } else {
            channelResults
        }
    }

    @ViewBuilder
    private var videoResults: some View {
        if !store.videos.isEmpty {
            Text(
                store.isShowingTrending
                    ? String.localised("discover.trending", table: .discover)
                    : String.localised("discover.results", table: .discover)
            )
            .font(.title3.bold())
            .foregroundStyle(Color.Text.primary)
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: videoColumns, spacing: 20) {
                ForEach(store.videos) { video in
                    DiscoverVideoCard(
                        video: video,
                        status: store.itemStatus[video.videoId],
                        isPending: store.pendingIds.contains(video.videoId),
                        showsChannel: true,
                        onAdd: { send(.addToQueueTapped(video, startNow: $0)) },
                        onChannelTapped: { send(.videoChannelTapped(video)) }
                    )
                    .onAppear {
                        if video == store.videos.last {
                            send(.lastItemAppeared)
                        }
                    }
                }
            }

            if store.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var channelResults: some View {
        LazyVGrid(columns: channelColumns, spacing: 12) {
            ForEach(store.channels) { channel in
                DiscoverChannelRow(
                    channel: channel,
                    isSubscribed: store.subscribedChannelIds.contains(channel.channelId),
                    isPending: store.pendingIds.contains(channel.channelId),
                    onTapped: { send(.channelTapped(channel)) },
                    onSubscribe: { send(.subscribeTapped(channel)) }
                )
                .onAppear {
                    if channel == store.channels.last {
                        send(.lastItemAppeared)
                    }
                }
            }
        }

        if store.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Chrome

    private var optionsMenu: some View {
        Menu {
            Picker(
                String.localised("discover.sort", table: .discover),
                selection: $store.order
            ) {
                ForEach(YouTubeSearchOrder.allCases, id: \.self) { order in
                    Text(order.title).tag(order)
                }
            }
            Divider()
            Button(
                String.localised("discover.changeKey", table: .discover),
                systemImage: "key"
            ) {
                send(.setUpKeyTapped)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(String.localised("discover.sort", table: .discover))
    }

    private var setupPrompt: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "safari",
                title: String.localised("discover.setup.intro.title", table: .discover),
                description: String.localised("discover.setup.intro.body", table: .discover)
            )
            Button {
                send(.setUpKeyTapped)
            } label: {
                Text(String.localised("discover.setup.start", table: .discover))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 48)
            }
            .background(Color.Accent.dark)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension YouTubeSearchOrder {
    var title: String {
        switch self {
        case .relevance: String.localised("discover.order.relevance", table: .discover)
        case .date: String.localised("discover.order.date", table: .discover)
        case .viewCount: String.localised("discover.order.viewCount", table: .discover)
        case .rating: String.localised("discover.order.rating", table: .discover)
        }
    }
}

/// A banner for quota exhaustion or a failed load.
struct DiscoverNotice: View {
    let icon: String
    let title: String
    let message: String
    let retryTitle: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.Brand.secondary)
            if let retryTitle {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.bordered)
                    .tint(Color.Accent.dark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.Surface.highlight.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
