#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchVideoListView: View {
    let viewModel: WatchVideoListViewModel

    public init(viewModel: WatchVideoListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            WatchVideoListContent(viewModel: viewModel)
                .navigationTitle(String(localized: "tab.videos", bundle: .module))
        }
    }
}

/// The list itself, shared by the Videos tab and a channel's screen.
struct WatchVideoListContent: View {
    let viewModel: WatchVideoListViewModel

    var body: some View {
        List {
            if viewModel.isEmpty {
                WatchListStatus(
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    emptyText: String(localized: "video.empty", bundle: .module)
                )
            } else {
                ForEach(viewModel.videos) { video in
                    NavigationLink(value: video) {
                        WatchVideoRow(
                            model: viewModel.rowModel(for: video),
                            config: viewModel.config
                        )
                    }
                    .task {
                        await viewModel.rowAppeared(video)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationDestination(for: VideoResponse.self) { video in
            WatchNowPlayingView(viewModel: viewModel.player(for: video))
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
