#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// "View All" destination pushed onto the home navigation stack from
/// `TVHomeVideoRow`. Mirrors `TVVideoListScreen`'s grid look but binds
/// to `FilteredVideoListReducer` so each filter loads paginated results
/// independently of the home page's flat video list.
@ViewAction(for: FilteredVideoListReducer.self)
public struct TVFilteredVideoListScreen: View {
    public var store: StoreOf<FilteredVideoListReducer>

    public init(store: StoreOf<FilteredVideoListReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 48)]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(store.filter.label, systemImage: store.filter.icon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 48)
                    .padding(.top, 32)

                if store.hasLoaded && store.displayedVideos.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 48) {
                        if store.isLoading && store.videos.isEmpty {
                            ForEach(VideoResponse.placeholders) { video in
                                TVVideoCardView(
                                    video: video,
                                    serverConfig: store.serverConfig
                                )
                                .redacted(reason: .placeholder)
                            }
                        } else {
                            ForEach(store.displayedVideos) { item in
                                TVVideoCardView(
                                    video: item.video,
                                    serverConfig: store.serverConfig
                                ) {
                                    send(.videoTapped(item.video))
                                }
                                .contextMenu {
                                    Button {
                                        send(.markAsWatchedTapped(item.video))
                                    } label: {
                                        Label(
                                            item.video.isWatched
                                                ? String.localised("video.markAsUnwatched", table: .videos)
                                                : String.localised("video.markAsWatched", table: .videos),
                                            systemImage: item.video.isWatched ? "eye.slash" : "eye"
                                        )
                                    }
                                    Button(role: .destructive) {
                                        send(.deleteFromServerTapped(item.video))
                                    } label: {
                                        Label(
                                            String.localised("video.deleteFromServer", table: .videos),
                                            systemImage: "trash"
                                        )
                                    }
                                }
                                .onAppear {
                                    if item.video.id == store.videos.last?.id {
                                        send(.lastItemAppeared)
                                    }
                                }
                            }
                        }
                    }
                    .padding(48)
                    .focusSection()

                    if store.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            if store.videos.isEmpty {
                send(.viewDidAppear)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)
            Image(systemName: store.filter.icon)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String.localised("video.empty.noVideos", table: .videos))
                .font(.title2)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
