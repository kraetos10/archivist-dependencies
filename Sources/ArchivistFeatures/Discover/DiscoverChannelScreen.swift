#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// A channel's latest uploads, pushed from Discover. It shares Discover's
/// store, so queue and subscribe state stays in step with the feed behind it.
@ViewAction(for: DiscoverReducer.self)
struct DiscoverChannelScreen: View {
    @Bindable var store: StoreOf<DiscoverReducer>

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let channel = store.browsedChannel {
                    header(channel)
                }

                if let message = store.errorMessage {
                    DiscoverNotice(
                        icon: "wifi.exclamationmark",
                        title: String.localised("discover.error.title", table: .discover),
                        message: message,
                        retryTitle: String.localised("discover.error.retry", table: .discover),
                        onRetry: { send(.retryTapped) }
                    )
                }

                if store.isLoadingChannelVideos {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if !store.channelVideos.isEmpty {
                    Text(String.localised("discover.latestUploads", table: .discover))
                        .font(.title3.bold())
                        .foregroundStyle(Color.Text.primary)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(store.channelVideos) { video in
                            DiscoverVideoCard(
                                video: video,
                                status: store.itemStatus[video.videoId],
                                isPending: store.pendingIds.contains(video.videoId),
                                showsChannel: false,
                                onAdd: { send(.addToQueueTapped(video, startNow: $0)) },
                                onChannelTapped: {}
                            )
                            .onAppear {
                                if video == store.channelVideos.last {
                                    send(.channelLastItemAppeared)
                                }
                            }
                        }
                    }

                    if store.isLoadingMoreChannelVideos {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.Brand.primary)
        .navigationTitle(store.browsedChannel?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ channel: YouTubeChannel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ChannelThumbView(url: channel.thumbnailURL, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.title)
                        .font(.title3.bold())
                        .foregroundStyle(Color.Text.primary)
                    if !channel.statsText.isEmpty {
                        Text(channel.statsText)
                            .font(.caption)
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !channel.channelDescription.isEmpty {
                Text(channel.channelDescription)
                    .font(.footnote)
                    .foregroundStyle(Color.Brand.secondary)
                    .lineLimit(3)
            }
            DiscoverSubscribeButton(
                isSubscribed: store.subscribedChannelIds.contains(channel.channelId),
                isPending: store.pendingIds.contains(channel.channelId),
                action: { send(.subscribeTapped(channel)) }
            )
        }
    }
}
#endif
