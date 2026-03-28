#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchPlaylistsListView: View {
    @State var viewModel: WatchPlaylistsViewModel
    let appState: WatchAppState

    public init(
        viewModel: WatchPlaylistsViewModel,
        appState: WatchAppState
    ) {
        self.viewModel = viewModel
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.playlists.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.playlists.isEmpty {
                    Text(String(localized: "playlist.empty", bundle: .module))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.playlists) { playlist in
                        NavigationLink(value: playlist) {
                            HStack(spacing: 10) {
                                WatchThumbnail(
                                    path: playlist.playlistThumbnail,
                                    config: viewModel.config
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.playlistName)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Text("\(playlist.entryCount) videos")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onAppear {
                            viewModel.loadNextPageIfNeeded(currentItem: playlist)
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
                if let config = appState.serverConfig {
                    WatchPlaylistDetailView(
                        viewModel: WatchPlaylistDetailViewModel(
                            config: config,
                            playlistId: playlist.playlistId
                        ),
                        playlist: playlist
                    )
                }
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
