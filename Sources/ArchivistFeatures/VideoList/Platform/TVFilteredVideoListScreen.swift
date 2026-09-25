#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// "View All" destination pushed onto the home navigation stack from
/// `TVHomeVideoRow`. Binds to `FilteredVideoListReducer` so each filter
/// loads paginated results independently of the home page's flat video list.
@ViewAction(for: FilteredVideoListReducer.self)
public struct TVFilteredVideoListScreen: View {
    public var store: StoreOf<FilteredVideoListReducer>

    public init(store: StoreOf<FilteredVideoListReducer>) {
        self.store = store
    }

    /// The card with focus, by video ID.
    @FocusState private var focusedVideoId: String?

    public var body: some View {
        // Read once per pass: `displayedVideos` filters, searches and maps
        // the whole list on every access.
        let displayed = store.displayedVideos
        let firstVideoId = displayed.first?.id

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(store.filter.label, systemImage: store.filter.icon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                if store.hasLoaded && displayed.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: TVLayout.cardGridColumns, spacing: TVLayout.cardSpacing) {
                        if store.isLoading && store.videos.isEmpty {
                            // Disabled so focus can't park on a placeholder
                            // and be lost when the real cards replace it.
                            ForEach(VideoResponse.placeholders) { video in
                                TVVideoCardView(
                                    video: video,
                                    serverConfig: store.serverConfig
                                )
                                .redacted(reason: .placeholder)
                                .disabled(true)
                            }
                        } else {
                            ForEach(displayed) { item in
                                TVVideoCardView(
                                    video: item.video,
                                    serverConfig: store.serverConfig
                                ) {
                                    send(.videoTapped(item.video))
                                }
                                .tvVideoContextMenu(
                                    video: item.video,
                                    onMarkWatched: { send(.markAsWatchedTapped(item.video)) },
                                    onDelete: { send(.deleteFromServerTapped(item.video)) }
                                )
                                .focused($focusedVideoId, equals: item.id)
                                .onAppear {
                                    // Anchored on the list actually shown —
                                    // see FilteredVideoListScreen.
                                    if item.id == displayed.last?.id {
                                        send(.lastItemAppeared)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, TVLayout.rowVerticalPadding)
                    .focusSection()

                    if store.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .defaultFocus($focusedVideoId, firstVideoId)
        // The grid is still placeholders when the screen is pushed, so
        // there's nothing to default to yet: put focus on the first card
        // once the first page arrives.
        .onChange(of: firstVideoId) { oldId, newId in
            if oldId == nil, focusedVideoId == nil {
                focusedVideoId = newId
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
                .scaledSystemFont(size: 64, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(.secondary)
            Text(String.localised("video.empty.noVideos", table: .videos))
                .font(.title2)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
