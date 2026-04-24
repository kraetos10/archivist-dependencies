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
        ScrollView {
            if store.hasLoaded && store.displayedVideos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: store.filter.icon)
                        .font(.system(size: 48))
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
                        ForEach(store.displayedVideos) { item in
                            VideoCardView(
                                video: item.video,
                                serverConfig: store.serverConfig,
                                isDownloaded: item.isDownloaded
                            )
                            .pressable { send(.videoTapped(item.video)) }
                            .onAppear {
                                if item.video.id == store.videos.last?.id {
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
