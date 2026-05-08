#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct TVHomeScreen: View {
    @Bindable public var store: StoreOf<TabReducer>

    public init(store: StoreOf<TabReducer>) {
        self.store = store
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

    private var continueWatchingVideos: [VideoResponse] {
        store.videoList.videos.filter { $0.isPartiallyWatched }
    }

    private var unwatchedVideos: [VideoResponse] {
        store.videoList.videos
            .filter { !$0.isWatched }
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.publishedDate, let rhsDate = rhs.publishedDate else {
                    return lhs.publishedDate != nil
                }
                return lhsDate > rhsDate
            }
    }

    private var allVideos: [VideoResponse] {
        store.videoList.videos
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.publishedDate, let rhsDate = rhs.publishedDate else {
                    return lhs.publishedDate != nil
                }
                return lhsDate > rhsDate
            }
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.videoList.path, action: \.videoList.path)) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 48) {
                    if store.videoList.isLoading && store.videoList.videos.isEmpty {
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
                        if !continueWatchingVideos.isEmpty {
                            TVHomeVideoRow(
                                title: WatchFilter.continueWatching.label,
                                icon: WatchFilter.continueWatching.icon,
                                videos: continueWatchingVideos,
                                serverConfig: store.videoList.serverConfig,
                                onVideoTapped: { video in
                                    store.send(.videoList(.view(.videoTapped(video))))
                                },
                                onViewAll: {
                                    store.send(.videoList(.view(.viewAllTapped(.continueWatching))))
                                }
                            )
                        }

                        if !unwatchedVideos.isEmpty {
                            TVHomeVideoRow(
                                title: WatchFilter.unwatched.label,
                                icon: WatchFilter.unwatched.icon,
                                videos: unwatchedVideos,
                                serverConfig: store.videoList.serverConfig,
                                onVideoTapped: { video in
                                    store.send(.videoList(.view(.videoTapped(video))))
                                },
                                onViewAll: {
                                    store.send(.videoList(.view(.viewAllTapped(.unwatched))))
                                }
                            )
                        }
                    }

                    if !store.channels.channels.isEmpty {
                        TVHomeChannelsRow(
                            channels: Array(store.channels.channels),
                            serverConfig: store.channels.serverConfig,
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

                    if !allVideos.isEmpty {
                        TVHomeVideoRow(
                            title: String(localized: "All Videos"),
                            icon: WatchFilter.all.icon,
                            videos: allVideos,
                            serverConfig: store.videoList.serverConfig,
                            onVideoTapped: { video in
                                store.send(.videoList(.view(.videoTapped(video))))
                            },
                            onViewAll: {
                                store.send(.videoList(.view(.viewAllTapped(.all))))
                            }
                        )
                    }

                    if !store.playlists.playlists.isEmpty {
                        TVHomePlaylistsRow(
                            playlists: Array(store.playlists.playlists),
                            serverConfig: store.playlists.serverConfig,
                            onPlaylistTapped: { playlist in
                                store.send(.homePlaylistTapped(playlist))
                            },
                            onViewAll: {
                                store.send(.setPresentingAllPlaylists(true))
                            }
                        )
                    }
                }
                .padding(.vertical, 48)
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
                if !presenting { refreshHome() }
            }
            .onChange(of: store.presentingAllPlaylists) { _, presenting in
                if !presenting { refreshHome() }
            }
            .onChange(of: store.channels.selectedChannel?.channel.channelId) { _, id in
                if id == nil { refreshHome() }
            }
            .onChange(of: store.playlists.selectedPlaylist?.playlist.playlistId) { _, id in
                if id == nil { refreshHome() }
            }
            .onChange(of: store.videoList.path.count) { oldCount, newCount in
                if oldCount > 0, newCount == 0 { refreshHome() }
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
}
#endif
