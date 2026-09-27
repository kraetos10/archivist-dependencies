#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchPlaylistDetailView: View {
    let viewModel: WatchPlaylistDetailViewModel
    let playlist: PlaylistResponse

    public init(
        viewModel: WatchPlaylistDetailViewModel,
        playlist: PlaylistResponse
    ) {
        self.viewModel = viewModel
        self.playlist = playlist
    }

    public var body: some View {
        List {
            if viewModel.playableEntries.isEmpty {
                WatchListStatus(
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    emptyText: String(localized: "video.empty", bundle: .module)
                )
            } else {
                ForEach(viewModel.playableEntries) { entry in
                    NavigationLink(value: entry) {
                        WatchVideoRow(
                            model: viewModel.rowModel(for: entry),
                            config: viewModel.config
                        )
                    }
                }
            }
        }
        .navigationTitle(playlist.playlistName)
        .navigationDestination(for: PlaylistEntry.self) { entry in
            if let player = viewModel.player(for: entry) {
                WatchNowPlayingView(viewModel: player)
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
#endif
