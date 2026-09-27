#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchPlaylistsListView: View {
    let viewModel: WatchPlaylistsViewModel

    public init(viewModel: WatchPlaylistsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.playlists.isEmpty {
                    WatchListStatus(
                        isLoading: viewModel.isLoading,
                        errorMessage: viewModel.errorMessage,
                        emptyText: String(localized: "playlist.empty", bundle: .module)
                    )
                } else {
                    ForEach(viewModel.playlists) { playlist in
                        NavigationLink(value: playlist) {
                            HStack(spacing: 10) {
                                WatchThumbnail(
                                    url: viewModel.thumbnailURL(for: playlist),
                                    config: viewModel.config
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.playlistName)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Text(viewModel.videoCountText(for: playlist))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .task {
                            await viewModel.rowAppeared(playlist)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(String(localized: "tab.playlists", bundle: .module))
            .navigationDestination(for: PlaylistResponse.self) { playlist in
                WatchPlaylistDetailView(
                    viewModel: viewModel.detailViewModel(for: playlist),
                    playlist: playlist
                )
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.viewDidAppear()
            }
        }
    }
}
#endif
