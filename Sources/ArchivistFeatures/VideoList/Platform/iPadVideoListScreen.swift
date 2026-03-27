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

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 16)]

    public var body: some View {
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
                .popover(item: $store.scope(state: \.addVideo, action: \.addVideo)) { addVideoStore in
                    AddVideoScreen(store: addVideoStore)
                        .frame(width: 400)
                }
        }
        .background(Color.Brand.primary)
        .refreshable { await send(.pullToRefreshTriggered).finish() }
        .navigationTitle(String.localised("generic.home"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $store.searchQuery,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: String.localised("video.search", table: .videos)
        )
        .onAppear {
            store.useSplitView = true
            send(.viewDidAppear)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.playlistPicker, action: \.playlistPicker)) { pickerStore in
            PlaylistPickerScreen(store: pickerStore)
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pipRestoreRequested)) { _ in
            send(.pipRestoreNotificationReceived)
        }
    }

}
#endif
