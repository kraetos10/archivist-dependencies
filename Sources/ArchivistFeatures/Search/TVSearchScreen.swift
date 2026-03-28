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
            LazyVStack(alignment: .leading, spacing: 48) {
                if store.isSearching {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else if store.hasSearched && store.videoResults.isEmpty
                            && store.channelResults.isEmpty && store.playlistResults.isEmpty {
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
            .padding(.vertical, 48)
        }
        .searchable(text: $store.searchQuery, prompt: String(localized: "Search videos, channels, playlists"))
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                TVVideoDetailScreen(store: detailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
    }

    // MARK: - Videos

    private var videoResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String.localised("generic.videos", table: .generic))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(store.videoResults) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: store.serverConfig
                        ) {
                            send(.videoTapped(video))
                        }
                        .frame(width: 400)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Channels

    private var channelResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String.localised("generic.channels", table: .generic))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(store.channelResults) { channel in
                        TVChannelCardView(
                            channel: channel,
                            serverConfig: store.serverConfig
                        ) {
                            send(.channelTapped(channel))
                        }
                        .frame(width: 250)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Playlists

    private var playlistResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String.localised("generic.playlists", table: .generic))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(store.playlistResults) { playlist in
                        Button {
                            send(.playlistTapped(playlist))
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                if let thumbURL = playlist.thumbURL(config: store.serverConfig) {
                                    AsyncImage(url: thumbURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(16 / 9, contentMode: .fill)
                                        default:
                                            Rectangle()
                                                .fill(Color.Brand.secondary.opacity(0.3))
                                                .aspectRatio(16 / 9, contentMode: .fill)
                                        }
                                    }
                                    .frame(width: 300, height: 169)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Text(playlist.playlistName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.Text.primary)
                                    .lineLimit(1)

                                if let channel = playlist.playlistChannel {
                                    Text(channel)
                                        .font(.caption)
                                        .foregroundStyle(Color.Brand.secondary)
                                }
                            }
                            .frame(width: 300)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.Brand.secondary)
            Text(String(localized: "No results found"))
                .font(.headline)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}
#endif
