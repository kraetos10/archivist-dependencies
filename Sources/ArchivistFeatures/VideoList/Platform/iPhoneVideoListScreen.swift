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
                    .sheet(item: $store.scope(state: \.destination?.addVideo, action: \.destination.addVideo)) { addVideoStore in
                        AddVideoScreen(store: addVideoStore)
                    }
            }
            .background(Color.Brand.primary)
            .refreshable { send(.pullToRefreshTriggered) }
            .navigationTitle(String.localised("generic.home", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
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
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
        .sheet(item: $store.scope(state: \.destination?.playlistPicker, action: \.destination.playlistPicker)) { pickerStore in
            PlaylistPickerScreen(store: pickerStore)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.videoDetail, action: \.destination.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

    @ViewBuilder
    private var homeSections: some View {
        if store.isLoading && store.videos.isEmpty {
            LazyVStack(spacing: 20) {
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
            LazyVStack(spacing: 20) {
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
                            onToggleWatched: { send(.markAsWatchedTapped($0)) },
                            onDeleteFromServer: { send(.deleteFromServerTapped($0)) },
                            onViewAll: { send(.viewAllTapped(filter)) }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        // Read once per pass: `displayedVideos` filters, merges and maps
        // the whole list on every access.
        let displayed = store.displayedVideos
        if (store.hasLoaded || !store.isSearching) && displayed.isEmpty {
            VideoListEmptyState(
                isSearchActive: true,
                isSearching: store.isSearching,
                watchFilter: store.watchFilter
            )
        } else {
            LazyVGrid(columns: searchColumns, spacing: 16) {
                ForEach(displayed) { item in
                    VideoCardView(
                        video: item.video,
                        serverConfig: store.serverConfig,
                        isDownloaded: item.isDownloaded
                    )
                    .contextMenu {
                        VideoContextMenu(
                            youtubeURL: item.video.youtubeURL,
                            isDownloaded: item.isDownloaded,
                            isWatched: item.video.isWatched,
                            onPlayNext: { send(.playNextTapped(item.video)) },
                            onAddToPlaylist: { send(.addToPlaylistTapped(item.video)) },
                            onDownloadToDevice: { send(.downloadToDeviceTapped(item.video)) },
                            onDeleteFromDevice: item.isDownloaded ? {
                                send(.deleteFromDeviceTapped(item.video))
                            } : nil,
                            onToggleWatched: { send(.markAsWatchedTapped(item.video)) },
                            onDeleteFromServer: { send(.deleteFromServerTapped(item.video)) }
                        )
                    }
                    .pressable {
                        send(.videoTapped(item.video))
                    }
                }
            }
            .animation(.default, value: displayed.map(\.id))
            .padding()
        }
    }
}
#endif
