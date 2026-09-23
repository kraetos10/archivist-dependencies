#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

@ViewAction(for: FilteredVideoListReducer.self)
public struct FilteredVideoListScreen: View {
    @Bindable public var store: StoreOf<FilteredVideoListReducer>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(store: StoreOf<FilteredVideoListReducer>) {
        self.store = store
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    public var body: some View {
        // Read once per pass: `displayedVideos` filters, searches and maps
        // the whole list on every access.
        let displayed = store.displayedVideos

        return ScrollView {
            if store.hasLoaded && displayed.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: store.filter.icon)
                        .scaledSystemFont(size: 48, relativeTo: .largeTitle)
                        // Decorative: the adjacent label carries the meaning.
                        .accessibilityHidden(true)
                        .foregroundStyle(Color.Brand.secondary)
                    Text(String.localised("video.empty.noVideos", table: .videos))
                        .foregroundStyle(Color.Brand.secondary)
                }
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    if store.isLoading && store.videos.isEmpty {
                        ForEach(VideoResponse.placeholders) { video in
                            VideoCardView(video: video, serverConfig: store.serverConfig)
                                .redacted(reason: .placeholder)
                        }
                    } else {
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
                                    onDeleteFromDevice: item.isDownloaded
                                        ? { send(.deleteFromDeviceTapped(item.video)) }
                                        : nil,
                                    onToggleWatched: { send(.markAsWatchedTapped(item.video)) },
                                    onDeleteFromServer: { send(.deleteFromServerTapped(item.video)) }
                                )
                            }
                            .pressable { send(.videoTapped(item.video)) }
                            .onAppear {
                                // Anchored on the list actually shown:
                                // `videos` is the unfiltered page buffer,
                                // whose last item a filtered or searched list
                                // usually never renders — so paging stopped
                                // after page 1.
                                if item.id == displayed.last?.id {
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
        .background(Color.Brand.primary)
        .refreshable { send(.pullToRefreshTriggered) }
        .navigationTitle(store.filter.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        .onAppear { send(.viewDidAppear) }
    }
}
#endif
