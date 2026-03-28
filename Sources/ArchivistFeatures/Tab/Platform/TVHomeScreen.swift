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
                            title: String(localized: "Continue Watching"),
                            serverConfig: store.videoList.serverConfig
                        )
                        TVHomeVideoRowPlaceholder(
                            title: String(localized: "Unwatched"),
                            serverConfig: store.videoList.serverConfig
                        )
                    } else {
                        if !continueWatchingVideos.isEmpty {
                            TVHomeVideoRow(
                                title: String(localized: "Continue Watching"),
                                videos: continueWatchingVideos,
                                serverConfig: store.videoList.serverConfig
                            ) { video in
                                store.send(.videoList(.view(.videoTapped(video))))
                            }
                        }

                        if !unwatchedVideos.isEmpty {
                            TVHomeVideoRow(
                                title: String(localized: "Unwatched"),
                                videos: unwatchedVideos,
                                serverConfig: store.videoList.serverConfig
                            ) { video in
                                store.send(.videoList(.view(.videoTapped(video))))
                            }
                        }
                    }

                    if !store.channels.channels.isEmpty {
                        TVHomeChannelsRow(
                            channels: Array(store.channels.channels),
                            serverConfig: store.channels.serverConfig
                        ) { channel in
                            store.send(.homeChannelTapped(channel))
                        }
                    } else if store.channels.isLoading {
                        TVHomeChannelsRowPlaceholder(
                            serverConfig: store.channels.serverConfig
                        )
                    }

                    if !allVideos.isEmpty {
                        TVHomeVideoRow(
                            title: String(localized: "All Videos"),
                            videos: allVideos,
                            serverConfig: store.videoList.serverConfig
                        ) { video in
                            store.send(.videoList(.view(.videoTapped(video))))
                        }
                    }

                    if !store.playlists.playlists.isEmpty {
                        TVHomePlaylistsRow(
                            playlists: Array(store.playlists.playlists),
                            serverConfig: store.playlists.serverConfig
                        ) { playlist in
                            store.send(.homePlaylistTapped(playlist))
                        }
                    }
                }
                .padding(.vertical, 48)
            }
            .onAppear {
                store.send(.videoList(.view(.viewDidAppear)))
                store.send(.channels(.view(.viewDidAppear)))
                store.send(.playlists(.view(.viewDidAppear)))
            }
        } destination: { store in
            switch store.case {
            case .videoDetail(let detailStore):
                TVVideoDetailScreen(store: detailStore)
            }
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
