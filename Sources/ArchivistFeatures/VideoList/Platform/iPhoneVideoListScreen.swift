#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoListReducer.self)
public struct iPhoneVideoListScreen: View {
    @Bindable public var store: StoreOf<VideoListReducer>

    public init(store: StoreOf<VideoListReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.flexible())]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                if !store.isSearchActive {
                    WatchFilterRow(watchFilter: store.watchFilter, showDownloadedOnly: store.showDownloadedOnly, onFilterChanged: { send(.watchFilterChanged($0), animation: .default) }, onDownloadedFilterTapped: { send(.downloadedFilterTapped) })
                        .padding(.top, 8)
                }

                if (store.hasLoaded || (store.isSearchActive && !store.isSearching)) && store.displayedVideos.isEmpty {
                    VideoListEmptyState(isSearchActive: store.isSearchActive, isSearching: store.isSearching, showDownloadedOnly: store.showDownloadedOnly, watchFilter: store.watchFilter)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        if store.isLoading && store.videos.isEmpty {
                            ForEach(VideoResponse.placeholders) { video in
                                VideoCardView(
                                    video: video,
                                    serverConfig: store.serverConfig
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.displayedVideos) { video in
                                VideoCardView(
                                    video: video,
                                    serverConfig: store.serverConfig
                                )
                                .contextMenu {
                                    VideoContextMenu(
                                        youtubeURL: video.youtubeURL,
                                        onPlayNext: { send(.playNextTapped(video)) },
                                        onAddToPlaylist: { send(.addToPlaylistTapped(video)) },
                                        onDownloadToDevice: { send(.downloadToDeviceTapped(video)) },
                                        onMarkAsWatched: { send(.markAsWatchedTapped(video)) },
                                        onDeleteFromServer: { send(.deleteFromServerTapped(video)) }
                                    )
                                }
                                .pressable {
                                    send(.videoTapped(video))
                                }
                                .onAppear {
                                    if video.id == store.videos.last?.id {
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
            .safeAreaInset(edge: .bottom) {
                FloatingAddButton { send(.addVideoTapped) }
                    .sheet(item: $store.scope(state: \.addVideo, action: \.addVideo)) { addVideoStore in
                        AddVideoScreen(store: addVideoStore)
                    }
            }
            .background(Color.Brand.primary)
            .refreshable { await send(.pullToRefreshTriggered).finish() }
            .navigationTitle(String(localized: "Home"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String(localized: "Search videos")
            )
        } destination: { store in
            switch store.case {
            case .videoDetail(let detailStore):
                VideoDetailScreen(store: detailStore)
            }
        }

        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.playlistPicker, action: \.playlistPicker)) { pickerStore in
            PlaylistPickerScreen(store: pickerStore)
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

}
#endif
