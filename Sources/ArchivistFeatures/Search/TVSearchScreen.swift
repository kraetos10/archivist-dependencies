#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: TVSearchReducer.self)
public struct TVSearchScreen: View {
    @Bindable public var store: StoreOf<TVSearchReducer>

    public init(store: StoreOf<TVSearchReducer>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if store.isSearching {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else if store.hasNoResults {
                    emptyState
                } else {
                    if !store.videoResults.isEmpty {
                        videoResultsSection
                    }
                    if !store.channelResults.isEmpty {
                        channelResultsSection
                    }
                    if !store.playlistResults.isEmpty {
                        playlistResultsSection
                    }
                }
            }
        }
        .searchable(
            text: $store.searchQuery,
            prompt: String.localised("generic.searchPrompt", table: .generic)
        )
        .fullScreenCover(item: $store.scope(state: \.destination?.videoDetail, action: \.destination.videoDetail)) { detailStore in
            NavigationStack {
                TVVideoDetailScreen(store: detailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
        .fullScreenCover(
            item: $store.scope(state: \.destination?.channelDetail, action: \.destination.channelDetail)
        ) { channelDetailStore in
            NavigationStack {
                TVChannelDetailScreen(store: channelDetailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
            .fullScreenCover(
                item: $store.scope(state: \.nestedVideoDetail, action: \.nestedVideoDetail)
            ) { detailStore in
                nestedVideoDetail(detailStore)
            }
        }
        .fullScreenCover(
            item: $store.scope(state: \.destination?.playlistDetail, action: \.destination.playlistDetail)
        ) { playlistDetailStore in
            NavigationStack {
                TVPlaylistDetailScreen(store: playlistDetailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
            .fullScreenCover(
                item: $store.scope(state: \.nestedVideoDetail, action: \.nestedVideoDetail)
            ) { detailStore in
                nestedVideoDetail(detailStore)
            }
        }
    }

    /// A video opened from a channel or playlist, over that cover — as the
    /// home screen does it.
    private func nestedVideoDetail(_ detailStore: StoreOf<VideoDetailReducer>) -> some View {
        NavigationStack {
            TVVideoDetailScreen(store: detailStore)
                .background(Color.Brand.primary)
        }
        .background(Color.Brand.primary)
    }

    // MARK: - Sections

    private var videoResultsSection: some View {
        resultsSection(String.localised("generic.videos", table: .generic)) {
            ForEach(store.videoResults) { video in
                TVVideoCardView(
                    video: video,
                    serverConfig: store.serverConfig
                ) {
                    send(.videoTapped(video))
                }
                .frame(width: TVLayout.cardWidth)
                .tvVideoContextMenu(
                    video: video,
                    onMarkWatched: { send(.markAsWatchedTapped(video)) },
                    onDelete: { send(.deleteFromServerTapped(video)) }
                )
            }
        }
    }

    private var channelResultsSection: some View {
        resultsSection(String.localised("generic.channels", table: .generic)) {
            ForEach(store.channelResults) { channel in
                TVChannelCardView(
                    channel: channel,
                    serverConfig: store.serverConfig
                ) {
                    send(.channelTapped(channel))
                }
            }
        }
    }

    private var playlistResultsSection: some View {
        resultsSection(String.localised("generic.playlists", table: .generic)) {
            ForEach(store.playlistResults) { playlist in
                TVPlaylistCardView(
                    playlist: playlist,
                    serverConfig: store.serverConfig
                ) {
                    send(.playlistTapped(playlist))
                }
                .frame(width: TVLayout.cardWidth)
            }
        }
    }

    /// A titled horizontal row of result cards, laid out like the home rows.
    private func resultsSection<Cards: View>(
        _ title: String,
        @ViewBuilder cards: () -> Cards
    ) -> some View {
        VStack(alignment: .leading, spacing: TVLayout.sectionHeaderSpacing) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                    cards()
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .scaledSystemFont(size: 48, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(Color.Brand.secondary)
            Text(String.localised("generic.noResults", table: .generic))
                .font(.headline)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}
#endif
