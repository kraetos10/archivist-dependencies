#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct TVHomeScreen: View {
    @Bindable public var store: StoreOf<TabReducer>

    /// The home tile that has focus, if any.
    @FocusState private var focusedCard: TVHomeFocus?
    /// The tile focus was last on. Survives a detail, cover or pushed
    /// screen, so focus can go back to it when that closes.
    @State private var lastFocusedCard: TVHomeFocus?
    /// Set at launch and on every return to home, cleared once the user
    /// moves focus themselves. While set, focus follows `focusTarget` as
    /// rows load and refresh: the first card takes focus once data
    /// arrives, and a card a refresh removes hands focus to the first card
    /// of its row rather than wherever the focus engine lands.
    @State private var isPlacingFocus = true

    public init(store: StoreOf<TabReducer>) {
        self.store = store
    }

    private var focusTarget: TVHomeFocus? {
        TVHomeFocus.target(restoring: lastFocusedCard, in: store.tvHomeRowCards)
    }

    /// Kick off a fresh fetch for every home-screen row. `viewDidAppear`
    /// is used on the first run (rows still empty); `pullToRefreshTriggered`
    /// otherwise so existing content stays on screen while the network
    /// round-trip lands.
    private func refreshHome() {
        if store.videoList.videos.isEmpty {
            store.send(.videoList(.view(.viewDidAppear)))
        } else {
            store.send(.videoList(.view(.pullToRefreshTriggered)))
        }
        if store.channels.channels.isEmpty {
            store.send(.channels(.view(.viewDidAppear)))
        } else {
            store.send(.channels(.view(.pullToRefreshTriggered)))
        }
        if store.playlists.playlists.isEmpty {
            store.send(.playlists(.view(.viewDidAppear)))
        } else {
            store.send(.playlists(.view(.pullToRefreshTriggered)))
        }
    }

    /// A detail, cover or pushed screen closed: refresh the rows and put
    /// focus back on the tile the user left from.
    private func returnToHome() {
        refreshHome()
        isPlacingFocus = true
        // The closing screen is still in the hierarchy on this pass, so
        // focus can't land on home until the next one.
        Task { focusedCard = focusTarget }
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.videoList.path, action: \.videoList.path)) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    videoRows
                    channelsRow

                    if !store.tvHomeAllVideos.isEmpty {
                        videoRow(
                            .allVideos,
                            title: String.localised("generic.allVideos", table: .generic),
                            filter: .all,
                            videos: store.tvHomeAllVideos
                        )
                    }

                    if !store.tvHomePlaylists.isEmpty {
                        TVHomePlaylistsRow(
                            playlists: store.tvHomePlaylists,
                            serverConfig: store.playlists.serverConfig,
                            focus: $focusedCard,
                            onPlaylistTapped: { playlist in
                                store.send(.homePlaylistTapped(playlist))
                            },
                            onViewAll: {
                                store.send(.setPresentingAllPlaylists(true))
                            }
                        )
                    }
                }
            }
            .defaultFocus($focusedCard, focusTarget)
            .onChange(of: focusedCard) { _, card in
                guard let card else { return }
                if card != focusTarget { isPlacingFocus = false }
                lastFocusedCard = card
            }
            .onChange(of: focusTarget) { _, target in
                guard isPlacingFocus, store.isTVHomeFrontmost else { return }
                focusedCard = target
            }
            .onAppear { refreshHome() }
            // SwiftUI doesn't reliably fire `.onAppear` on the
            // underlying view when a `fullScreenCover` dismisses on
            // tvOS, so the home rows would otherwise stay stale every
            // time the user came back from a channel / playlist /
            // detail / view-all screen. Watch each cover/path piece of
            // state and re-refresh as it returns to the empty/inactive
            // value.
            .onChange(of: store.presentingAllChannels) { _, presenting in
                if !presenting { returnToHome() }
            }
            .onChange(of: store.presentingAllPlaylists) { _, presenting in
                if !presenting { returnToHome() }
            }
            .onChange(of: store.channels.selectedChannel?.channel.channelId) { _, id in
                if id == nil { returnToHome() }
            }
            .onChange(of: store.playlists.selectedPlaylist?.playlist.playlistId) { _, id in
                if id == nil { returnToHome() }
            }
            .onChange(of: store.videoList.path.count) { oldCount, newCount in
                if oldCount > 0, newCount == 0 { returnToHome() }
            }
        } destination: { store in
            switch store.case {
            case .videoDetail(let detailStore):
                TVVideoDetailScreen(store: detailStore)
            case .filteredList(let listStore):
                TVFilteredVideoListScreen(store: listStore)
            }
        }
        .fullScreenCover(
            isPresented: $store.presentingAllChannels.sending(\.setPresentingAllChannels)
        ) {
            NavigationStack {
                TVChannelsScreen(store: store.scope(state: \.channels, action: \.channels))
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
        .fullScreenCover(
            isPresented: $store.presentingAllPlaylists.sending(\.setPresentingAllPlaylists)
        ) {
            NavigationStack {
                TVPlaylistsScreen(store: store.scope(state: \.playlists, action: \.playlists))
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
        .fullScreenCover(
            item: $store.scope(state: \.channels.selectedChannel, action: \.channels.channelDetail)
        ) { channelDetailStore in
            NavigationStack {
                TVChannelDetailScreen(store: channelDetailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
            .fullScreenCover(
                item: $store.scope(state: \.channels.videoDetail, action: \.channels.videoDetail)
            ) { detailStore in
                NavigationStack {
                    TVVideoDetailScreen(store: detailStore)
                        .background(Color.Brand.primary)
                }
                .background(Color.Brand.primary)
            }
        }
        .fullScreenCover(
            item: $store.scope(state: \.playlists.selectedPlaylist, action: \.playlists.playlistDetail)
        ) { playlistDetailStore in
            NavigationStack {
                TVPlaylistDetailScreen(store: playlistDetailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
            .fullScreenCover(
                item: $store.scope(state: \.playlists.videoDetail, action: \.playlists.videoDetail)
            ) { detailStore in
                NavigationStack {
                    TVVideoDetailScreen(store: detailStore)
                        .background(Color.Brand.primary)
                }
                .background(Color.Brand.primary)
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private var videoRows: some View {
        if store.isTVHomeLoadingVideos {
            TVHomeVideoRowPlaceholder(
                title: WatchFilter.continueWatching.label,
                icon: WatchFilter.continueWatching.icon,
                serverConfig: store.videoList.serverConfig
            )
            TVHomeVideoRowPlaceholder(
                title: WatchFilter.unwatched.label,
                icon: WatchFilter.unwatched.icon,
                serverConfig: store.videoList.serverConfig
            )
        } else {
            if !store.tvHomeContinueWatching.isEmpty {
                videoRow(
                    .continueWatching,
                    title: WatchFilter.continueWatching.label,
                    filter: .continueWatching,
                    videos: store.tvHomeContinueWatching
                )
            }

            if !store.tvHomeUnwatched.isEmpty {
                videoRow(
                    .unwatched,
                    title: WatchFilter.unwatched.label,
                    filter: .unwatched,
                    videos: store.tvHomeUnwatched
                )
            }
        }
    }

    @ViewBuilder
    private var channelsRow: some View {
        if !store.tvHomeChannels.isEmpty {
            TVHomeChannelsRow(
                channels: store.tvHomeChannels,
                serverConfig: store.channels.serverConfig,
                focus: $focusedCard,
                onChannelTapped: { channel in
                    store.send(.homeChannelTapped(channel))
                },
                onViewAll: {
                    store.send(.setPresentingAllChannels(true))
                }
            )
        } else if store.channels.isLoading {
            TVHomeChannelsRowPlaceholder(
                serverConfig: store.channels.serverConfig
            )
        }
    }

    private func videoRow(
        _ row: TVHomeRow,
        title: String,
        filter: WatchFilter,
        videos: [VideoResponse]
    ) -> some View {
        TVHomeVideoRow(
            row: row,
            title: title,
            icon: filter.icon,
            videos: videos,
            serverConfig: store.videoList.serverConfig,
            focus: $focusedCard,
            onVideoTapped: { video in
                store.send(.videoList(.view(.videoTapped(video))))
            },
            onMarkWatched: { video in
                store.send(.videoList(.view(.markAsWatchedTapped(video))))
            },
            onDelete: { video in
                store.send(.videoList(.view(.deleteFromServerTapped(video))))
            },
            onViewAll: {
                store.send(.videoList(.view(.viewAllTapped(filter))))
            }
        )
    }
}

// MARK: - Focus

/// A tvOS home row, for focus bookkeeping.
enum TVHomeRow: Hashable, Sendable {
    case continueWatching
    case unwatched
    case channels
    case allVideos
    case playlists
}

/// The card IDs one home row shows, in order.
struct TVHomeRowCards: Equatable, Sendable {
    let row: TVHomeRow
    let ids: [String]
}

/// A focusable tile on the tvOS home screen: a card, keyed by its row and
/// item ID, or a row's trailing View All tile.
enum TVHomeFocus: Hashable, Sendable {
    case card(TVHomeRow, id: String)
    case viewAll(TVHomeRow)

    var row: TVHomeRow {
        switch self {
        case .card(let row, _), .viewAll(let row):
            row
        }
    }

    /// Where home focus belongs: `last` if that tile is still on screen,
    /// else the first card of its row, else the first card of the first
    /// row. Nil while nothing focusable is loaded.
    static func target(
        restoring last: TVHomeFocus?,
        in rows: [TVHomeRowCards]
    ) -> TVHomeFocus? {
        if let last, let ids = rows.first(where: { $0.row == last.row })?.ids {
            switch last {
            case .card(_, let id) where ids.contains(id):
                return last
            case .viewAll:
                return last
            case .card:
                if let first = ids.first { return .card(last.row, id: first) }
            }
        }
        guard let firstRow = rows.first, let firstId = firstRow.ids.first else { return nil }
        return .card(firstRow.row, id: firstId)
    }
}

// MARK: - Home content

extension TabReducer.State {
    /// Cards shown per home row, before its View All tile.
    static let tvHomeRowItemCap = 10

    var isTVHomeLoadingVideos: Bool {
        videoList.isLoading && videoList.videos.isEmpty
    }

    /// Partially watched videos.
    var tvHomeContinueWatching: [VideoResponse] {
        tvHomeVideos(for: .continueWatching)
    }

    /// Videos never started. In-progress ones sit in Continue Watching
    /// only, rather than in both rows.
    var tvHomeUnwatched: [VideoResponse] {
        tvHomeVideos(for: .unwatched)
    }

    var tvHomeAllVideos: [VideoResponse] {
        tvHomeVideos(for: .all)
    }

    var tvHomeChannels: [ChannelResponse] {
        Array(channels.channels.prefix(Self.tvHomeRowItemCap))
    }

    var tvHomePlaylists: [PlaylistResponse] {
        Array(playlists.playlists.prefix(Self.tvHomeRowItemCap))
    }

    /// True while nothing covers the home screen, so focus can be put on it.
    var isTVHomeFrontmost: Bool {
        selectedTab == .home
            && videoList.path.isEmpty
            && !presentingAllChannels
            && !presentingAllPlaylists
            && channels.selectedChannel == nil
            && playlists.selectedPlaylist == nil
    }

    /// Card IDs of each home row on screen, top to bottom. Rows only
    /// count with at least one card; placeholders aren't focusable.
    var tvHomeRowCards: [TVHomeRowCards] {
        var rows: [TVHomeRowCards] = []
        if !isTVHomeLoadingVideos {
            rows.append(TVHomeRowCards(row: .continueWatching, ids: tvHomeContinueWatching.map(\.videoId)))
            rows.append(TVHomeRowCards(row: .unwatched, ids: tvHomeUnwatched.map(\.videoId)))
        }
        rows.append(TVHomeRowCards(row: .channels, ids: tvHomeChannels.map(\.channelId)))
        rows.append(TVHomeRowCards(row: .allVideos, ids: tvHomeAllVideos.map(\.videoId)))
        rows.append(TVHomeRowCards(row: .playlists, ids: tvHomePlaylists.map(\.playlistId)))
        return rows.filter { !$0.ids.isEmpty }
    }

    /// The home carousel slice for `filter`, from the list reducer's
    /// pre-sorted cache (strict filters: Unwatched excludes in-progress).
    private func tvHomeVideos(for filter: WatchFilter) -> [VideoResponse] {
        let section = videoList.cachedHomeSections.first { $0.filter == filter }
        return Array((section?.videos ?? []).prefix(Self.tvHomeRowItemCap))
    }
}
#endif
