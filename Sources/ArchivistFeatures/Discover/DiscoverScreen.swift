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
    private let playlistColumns = [GridItem(.adaptive(minimum: 380), spacing: 12)]

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
                    if store.showsFilters {
                        ToolbarItem(placement: .topBarTrailing) {
                            filtersButton
                        }
                    }
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
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Picker(
                        String.localised("discover.title", table: .discover),
                        selection: $store.searchScope
                    ) {
                        Text(String.localised("discover.scope.videos", table: .discover))
                            .tag(DiscoverReducer.State.SearchScope.videos)
                        Text(String.localised("discover.scope.channels", table: .discover))
                            .tag(DiscoverReducer.State.SearchScope.channels)
                        Text(String.localised("discover.scope.playlists", table: .discover))
                            .tag(DiscoverReducer.State.SearchScope.playlists)
                    }
                    .pickerStyle(.segmented)

                    if let summary = store.filterSummary {
                        DiscoverFilterSummary(
                            text: summary,
                            onClear: { send(.resetFiltersTapped) }
                        )
                    }

                    if store.isQuotaExceeded {
                        DiscoverNotice(
                            icon: "hourglass",
                            title: String.localised("discover.quota.title", table: .discover),
                            message: [
                                String.localised("discover.quota.message", table: .discover),
                                store.quotaResetText
                            ]
                            .compactMap { $0 }
                            .joined(separator: " "),
                            retryTitle: nil,
                            onRetry: {},
                            linkTitle: String.localised("discover.quota.check", table: .discover),
                            linkURL: DiscoverQuota.consoleURL
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
                }
                .padding(.horizontal, 16)

                results
            }
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var results: some View {
        if store.showsSearchPrompt {
            searchPrompt
                .padding(.horizontal, 16)
        } else if store.isShowingTrending {
            browse
        } else if store.isLoading {
            loadingResults
                .padding(.horizontal, 16)
        } else if store.showsNoResults {
            EmptyStateView(
                icon: "magnifyingglass",
                title: String.localised("discover.empty.noResults.title", table: .discover),
                description: String.localised("discover.empty.noResults.description", table: .discover)
            )
            .padding(.horizontal, 16)
        } else {
            Group {
                switch store.searchScope {
                case .videos: searchVideoResults
                case .channels: channelResults
                case .playlists: playlistResults
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var loadingResults: some View {
        if store.searchScope == .videos {
            LazyVGrid(columns: videoColumns, spacing: 20) {
                ForEach(0..<6, id: \.self) { _ in
                    DiscoverCardSkeleton()
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        }
    }

    @ViewBuilder
    private var searchPrompt: some View {
        if store.searchScope == .playlists {
            EmptyStateView(
                icon: "rectangle.stack",
                title: String.localised("discover.empty.playlists.title", table: .discover),
                description: String.localised("discover.empty.playlists.description", table: .discover)
            )
        } else {
            EmptyStateView(
                icon: "person.2.wave.2",
                title: String.localised("discover.empty.channels.title", table: .discover),
                description: String.localised("discover.empty.channels.description", table: .discover)
            )
        }
    }

    // MARK: - Browse

    /// Nothing searched for: shelves from the archive, then Trending. A
    /// category only changes the Trending row; the rows above stay.
    private var browse: some View {
        VStack(alignment: .leading, spacing: 20) {
            if store.showsShelfSkeleton {
                DiscoverRowSkeleton()
                DiscoverRowSkeleton()
            }
            ForEach(store.shelves) { shelf in
                DiscoverShelfView(
                    shelf: shelf,
                    choices: store.state.choices(for: shelf),
                    isLoading: store.loadingShelfIds.contains(shelf.id),
                    status: { store.itemStatus[$0.videoId] },
                    isPending: { store.pendingIds.contains($0.videoId) },
                    onAdd: { send(.addToQueueTapped($0, startNow: $1)) },
                    onChannelTapped: { send(.videoChannelTapped($0)) },
                    onChoose: { send(.becauseVideoSelected(shelfId: shelf.id, $0)) }
                )
                .transition(.opacity)
            }
            if store.showsTrendingRow {
                trendingRow
            }
        }
        .animation(.smooth, value: store.showsShelfSkeleton)
        .animation(.smooth, value: store.shelves.map(\.id))
    }

    private var trendingRow: some View {
        DiscoverRow(
            resetKey: store.trendingCategory?.rawValue ?? "",
            header: {
                Label(
                    String.localised("discover.trending", table: .discover),
                    systemImage: "flame"
                )
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
                .accessibilityAddTraits(.isHeader)
            },
            subheader: {
                DiscoverCategoryChips(selected: store.trendingCategory) {
                    send(.categorySelected($0))
                }
            },
            content: { cardWidth in
                if store.showsTrendingSkeleton {
                    DiscoverCardSkeletons(cardWidth: cardWidth)
                } else if store.videos.isEmpty {
                    Text(String.localised("discover.empty.noResults.title", table: .discover))
                        .font(.subheadline)
                        .foregroundStyle(Color.Brand.secondary)
                        .frame(width: cardWidth, height: 120)
                } else {
                    ForEach(store.videos) { video in
                        DiscoverVideoCard(
                            video: video,
                            status: store.itemStatus[video.videoId],
                            isPending: store.pendingIds.contains(video.videoId),
                            showsChannel: true,
                            onAdd: { send(.addToQueueTapped(video, startNow: $0)) },
                            onChannelTapped: { send(.videoChannelTapped(video)) }
                        )
                        .frame(width: cardWidth)
                        .transition(.opacity)
                        .onAppear {
                            if video == store.videos.last {
                                send(.lastItemAppeared)
                            }
                        }
                    }
                    if store.isLoadingMore {
                        DiscoverCardSkeleton()
                            .frame(width: cardWidth)
                    }
                }
            }
        )
        .animation(.smooth, value: store.videos)
        .animation(.smooth, value: store.showsTrendingSkeleton)
        .animation(.smooth, value: store.trendingCategory)
        .transition(.opacity)
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchVideoResults: some View {
        if !store.videos.isEmpty {
            Text(String.localised("discover.results", table: .discover))
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
    private var playlistResults: some View {
        LazyVGrid(columns: playlistColumns, spacing: 12) {
            ForEach(store.playlists) { playlist in
                DiscoverPlaylistRow(
                    playlist: playlist,
                    isSubscribed: store.subscribedPlaylistIds.contains(playlist.playlistId),
                    isPending: store.pendingIds.contains(playlist.playlistId),
                    onSubscribe: { send(.subscribePlaylistTapped(playlist)) }
                )
                .onAppear {
                    if playlist == store.playlists.last {
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
            if store.searchScope == .videos {
                Picker(
                    String.localised("discover.filter.duration", table: .discover),
                    selection: $store.filters.duration
                ) {
                    ForEach(YouTubeSearchFilters.Duration.allCases, id: \.self) { duration in
                        Text(duration.title).tag(duration)
                    }
                }
                Picker(
                    String.localised("discover.filter.uploaded", table: .discover),
                    selection: $store.filters.uploaded
                ) {
                    ForEach(YouTubeSearchFilters.Uploaded.allCases, id: \.self) { uploaded in
                        Text(uploaded.title).tag(uploaded)
                    }
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
            Image(
                systemName: store.hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "ellipsis.circle"
            )
        }
        .accessibilityLabel(String.localised("discover.more", table: .discover))
    }

    /// Sort and filter, which only apply to a search, so it's only there
    /// once there is one.
    private var filtersButton: some View {
        Button {
            send(.filtersTapped)
        } label: {
            Label(
                String.localised("discover.filters.title", table: .discover),
                systemImage: store.hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .popover(isPresented: $store.isFiltersPresented) {
            DiscoverFiltersView(
                order: $store.order,
                duration: $store.filters.duration,
                uploaded: $store.filters.uploaded,
                showsVideoFilters: store.searchScope == .videos,
                hasActiveFilters: store.hasActiveFilters,
                onReset: { send(.resetFiltersTapped) }
            )
        }
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

/// A banner for quota exhaustion or a failed load.
struct DiscoverNotice: View {
    let icon: String
    let title: String
    let message: String
    let retryTitle: String?
    let onRetry: () -> Void
    var linkTitle: String?
    var linkURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.Brand.secondary)
            if let linkTitle, let linkURL {
                Link(linkTitle, destination: linkURL)
                    .font(.footnote.weight(.semibold))
                    .tint(Color.Accent.dark)
            }
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
