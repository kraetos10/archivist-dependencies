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

    private let searchColumns = [GridItem(.flexible())]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                if store.isSearchActive {
                    searchResultsSection
                } else {
                    homeSections
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
            case .filteredList(let listStore):
                FilteredVideoListScreen(store: listStore)
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

    @ViewBuilder
    private var homeSections: some View {
        if store.isLoading && store.videos.isEmpty {
            LazyVStack(spacing: 16) {
                ForEach(Array(VideoListReducer.State.homeSectionOrder.prefix(3)), id: \.self) { filter in
                    HomeFilterSectionPlaceholder(
                        filter: filter,
                        serverConfig: store.serverConfig,
                        cardWidth: 320
                    )
                }
            }
            .padding(.vertical, 8)
        } else if store.hasLoaded && store.videos.isEmpty {
            VideoListEmptyState(
                isSearchActive: false,
                isSearching: false,
                watchFilter: store.watchFilter
            )
        } else {
            LazyVStack(spacing: 16) {
                ForEach(VideoListReducer.State.homeSectionOrder, id: \.self) { filter in
                    let items = store.state.items(for: filter)
                    if !items.isEmpty {
                        HomeFilterSection(
                            filter: filter,
                            items: items,
                            serverConfig: store.serverConfig,
                            cardWidth: 320,
                            onVideoTapped: { send(.videoTapped($0)) },
                            onPlayNext: { send(.playNextTapped($0)) },
                            onAddToPlaylist: { send(.addToPlaylistTapped($0)) },
                            onDownloadToDevice: { send(.downloadToDeviceTapped($0)) },
                            onDeleteFromDevice: { send(.deleteFromDeviceTapped($0)) },
                            onMarkAsWatched: { send(.markAsWatchedTapped($0)) },
                            onDeleteFromServer: { send(.deleteFromServerTapped($0)) },
                            onViewAll: { send(.viewAllTapped(filter)) }
                        )
                    }
                }

                // Trigger pagination when the user scrolls to the end of the
                // last section — each carousel only renders a capped slice so
                // we can't rely on per-card onAppear like the old flat list.
                Color.clear
                    .frame(height: 1)
                    .onAppear { send(.lastItemAppeared) }

                if store.isLoadingMore {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .padding()
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if (store.hasLoaded || !store.isSearching) && store.displayedVideos.isEmpty {
            VideoListEmptyState(
                isSearchActive: true,
                isSearching: store.isSearching,
                watchFilter: store.watchFilter
            )
        } else {
            LazyVGrid(columns: searchColumns, spacing: 16) {
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
                }
            }
            .animation(.default, value: store.displayedVideos.map(\.id))
            .padding()
        }
    }
}
#endif
