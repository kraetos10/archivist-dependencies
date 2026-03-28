#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchChannelDetailView: View {
    @State var viewModel: WatchChannelDetailViewModel
    let channel: ChannelResponse

    public init(
        viewModel: WatchChannelDetailViewModel,
        channel: ChannelResponse
    ) {
        self.viewModel = viewModel
        self.channel = channel
    }

    public var body: some View {
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
        .navigationTitle(channel.channelName)
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
        .task {
            await viewModel.viewDidAppear()
        }
    }
}
#endif
