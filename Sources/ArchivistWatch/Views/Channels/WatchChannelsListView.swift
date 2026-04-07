#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchChannelsListView: View {
    @State var viewModel: WatchChannelsViewModel
    let appState: WatchAppState

    public init(
        viewModel: WatchChannelsViewModel,
        appState: WatchAppState
    ) {
        self.viewModel = viewModel
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.channels.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.channels.isEmpty {
                    Text(String(localized: "channel.empty", bundle: .module))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.channels) { channel in
                        NavigationLink(value: channel) {
                            HStack(spacing: 10) {
                                WatchChannelThumb(
                                    path: channel.channelThumbUrl,
                                    config: viewModel.config
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.channelName)
                                        .font(.headline)
                                        .lineLimit(1)

                                    if let subs = channel.formattedSubs {
                                        Text("\(subs) subscribers")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onAppear {
                            viewModel.loadNextPageIfNeeded(currentItem: channel)
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
                if let config = appState.serverConfig {
                    WatchChannelDetailView(
                        viewModel: WatchChannelDetailViewModel(
                            config: config,
                            channelId: channel.channelId
                        ),
                        channel: channel
                    )
                }
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
