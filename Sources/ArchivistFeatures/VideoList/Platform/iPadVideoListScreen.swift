#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoListReducer.self)
public struct iPadVideoListScreen: View {
    @Bindable public var store: StoreOf<VideoListReducer>

    public init(store: StoreOf<VideoListReducer>) {
        self.store = store
    }

    private let searchColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

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
                HStack {
                    Spacer()
                    FloatingAddButton(action: { send(.addVideoTapped) })
                        .button
                        .popover(item: $store.scope(state: \.destination?.addVideo, action: \.destination.addVideo)) { addVideoStore in
                            AddVideoScreen(store: addVideoStore)
                                .frame(width: 400)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 8)
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
            .onAppear { send(.viewDidAppear) }
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
            .sheet(item: $store.scope(state: \.destination?.playlistPicker, action: \.destination.playlistPicker)) { pickerStore in
                PlaylistPickerScreen(store: pickerStore)
            }
        } destination: { store in
            switch store.case {
            case .videoDetail(let detailStore):
                VideoDetailScreen(store: detailStore)
            case .filteredList(let listStore):
                FilteredVideoListScreen(store: listStore)
            }
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
                        cardWidth: 340
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
                            cardWidth: 340,
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

                // Fixed-height pagination footer so toggling the spinner
                // doesn't reflow the LazyVStack and remount the sentinel
                // mid-scroll (which produced choppy scrolling near the
                // bottom while the next page was loading).
                ZStack {
                    if store.isLoadingMore {
                        ProgressView().tint(Color.Progress.tint)
                    }
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .id("paginationSentinel")
                .onAppear { send(.lastItemAppeared) }
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
