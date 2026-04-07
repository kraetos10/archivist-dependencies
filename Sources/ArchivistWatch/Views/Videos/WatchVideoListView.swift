#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchVideoListView: View {
    @State var viewModel: WatchVideoListViewModel

    public init(viewModel: WatchVideoListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.videos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.videos.isEmpty {
                    Text(String(localized: "video.empty", bundle: .module))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.videos) { video in
                        NavigationLink(value: video) {
                            WatchVideoRow(
                                title: video.title,
                                thumbPath: video.vidThumbUrl,
                                config: viewModel.config,
                                videoId: video.videoId,
                                isWatched: video.isWatched,
                                watchProgress: video.watchProgress,
                                durationStr: video.durationStr,
                                remainingStr: video.remainingStr
                            )
                        }
                        .onAppear {
                            viewModel.loadNextPageIfNeeded(currentItem: video)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(String(localized: "tab.videos", bundle: .module))
            .navigationDestination(for: VideoResponse.self) { video in
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
}
#endif
