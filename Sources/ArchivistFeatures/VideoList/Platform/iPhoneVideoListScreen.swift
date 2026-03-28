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
                    WatchFilterRow(
                        watchFilter: store.watchFilter,
                        onFilterChanged: { send(.watchFilterChanged($0), animation: .default) }
                    )
                        .padding(.top, 8)
                }

                if (store.hasLoaded || (store.isSearchActive && !store.isSearching)) && store.displayedVideos.isEmpty {
                    VideoListEmptyState(
                        isSearchActive: store.isSearchActive,
                        isSearching: store.isSearching,
                        watchFilter: store.watchFilter
                    )
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
                            ForEach(store.displayedVideos) { item in
                                VideoCardView(
                                    video: item.video,
                                    serverConfig: store.serverConfig,
                                    isDownloaded: item.isDownloaded
                                )
                                .contextMenu {
                                    VideoContextMenu(
                                        youtubeURL: item.video.youtubeURL,
                                        isDownloaded: item.isDownloaded,
                                        onPlayNext: { send(.playNextTapped(item.video)) },
                                        onAddToPlaylist: { send(.addToPlaylistTapped(item.video)) },
                                        onDownloadToDevice: { send(.downloadToDeviceTapped(item.video)) },
                                        onDeleteFromDevice: item.isDownloaded ? {
                                            send(.deleteFromDeviceTapped(item.video))
                                        } : nil,
                                        onMarkAsWatched: { send(.markAsWatchedTapped(item.video)) },
                                        onDeleteFromServer: { send(.deleteFromServerTapped(item.video)) }
                                    )
                                }
                                .pressable {
                                    send(.videoTapped(item.video))
                                }
                                .onAppear {
                                    if item.video.id == store.videos.last?.id {
                                        send(.lastItemAppeared)
                                    }
                                }
                            }
                        }
                    }
                    .animation(.default, value: store.displayedVideos.map(\.id))
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
            .refreshable { send(.pullToRefreshTriggered) }
            .navigationTitle(String.localised("generic.home", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    VideoSortMenu(current: store.sortOrder) { sort in
                        send(.sortOrderChanged(sort), animation: .default)
                    }
                }
            }
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String.localised("video.search", table: .videos)
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
