#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchPlaylistDetailView: View {
    @State var viewModel: WatchPlaylistDetailViewModel
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
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.entries.isEmpty {
                Text(String(localized: "video.empty", bundle: Bundle.module))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.entries) { entry in
                    Button {
                        viewModel.playEntry(entry)
                    } label: {
                        WatchVideoRow(
                            title: entry.title ?? String(localized: "generic.unknown", bundle: Bundle.module),
                            thumbURL: entry.thumbURL(config: viewModel.config),
                            config: viewModel.config,
                            videoId: entry.youtubeId ?? "",
                            isWatched: false,
                            watchProgress: 0,
                            durationStr: nil,
                            remainingStr: nil
                        )
                    }
                }
            }
        }
        .navigationTitle(playlist.playlistName)
        .overlay {
            if viewModel.isLoadingVideo {
                ProgressView()
            }
        }
        .navigationDestination(item: $viewModel.loadedVideo) { video in
            WatchNowPlayingView(
                viewModel: WatchAudioPlayerViewModel(
                    video: video,
                    serverConfig: viewModel.config
                )
            )
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            Task { await viewModel.viewDidAppear() }
        }
    }
}
#endif
