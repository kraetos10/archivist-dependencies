#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchChannelsListView: View {
    let viewModel: WatchChannelsViewModel

    public init(viewModel: WatchChannelsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.channels.isEmpty {
                    WatchListStatus(
                        isLoading: viewModel.isLoading,
                        errorMessage: viewModel.errorMessage,
                        emptyText: String(localized: "channel.empty", bundle: .module)
                    )
                } else {
                    ForEach(viewModel.channels) { channel in
                        NavigationLink(value: channel) {
                            HStack(spacing: 10) {
                                WatchChannelThumb(
                                    url: viewModel.thumbnailURL(for: channel),
                                    config: viewModel.config
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.channelName)
                                        .font(.headline)
                                        .lineLimit(1)

                                    if let subscribers = viewModel.subscribersText(for: channel) {
                                        Text(subscribers)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .task {
                            await viewModel.rowAppeared(channel)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(String(localized: "tab.channels", bundle: .module))
            .navigationDestination(for: ChannelResponse.self) { channel in
                WatchChannelDetailView(
                    viewModel: viewModel.detailViewModel(for: channel),
                    channel: channel
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
