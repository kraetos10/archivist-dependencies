#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The scrolling channel list shared by the iPhone and iPad screens: filter
/// pills, the empty / placeholder states, and the card grid.
@ViewAction(for: ChannelsReducer.self)
struct ChannelsGridContent: View {
    let store: StoreOf<ChannelsReducer>
    let columns: [GridItem]
    /// iPad split view outlines the channel shown in the detail column.
    let highlightsSelection: Bool

    var body: some View {
        // Read once per pass: `content` filters and merges every channel.
        let content = store.content
        let selectedId = highlightsSelection ? store.selectedChannel?.channel.channelId : nil

        ScrollView {
            ChannelsFilterRow(store: store)
                .padding(.horizontal)
                .padding(.top, 8)

            switch content {
            case .emptyUnwatched:
                EmptyStateView(
                    icon: "eye.slash",
                    title: String.localised("video.empty.noUnwatched", table: .videos),
                    description: String.localised("generic.noNewVideosDescription", table: .generic)
                )
            case .noChannels:
                EmptyStateView(
                    icon: "person.2.rectangle.stack",
                    title: String.localised("login.noChannels", table: .login),
                    description: String.localised("login.subscribeChannelsDescription", table: .login)
                )
            case .noSearchResults:
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String.localised("video.empty.noSearchResults", table: .videos),
                    description: String.localised("video.empty.tryDifferentSearch", table: .videos)
                )
            case .placeholders:
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ChannelResponse.placeholders) { channel in
                        ChannelCardView(
                            channel: channel,
                            serverConfig: store.serverConfig
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding()
            case .channels(let channels):
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(channels) { channel in
                        let isSelected = channel.channelId == selectedId
                        ChannelCardView(
                            channel: channel,
                            serverConfig: store.serverConfig
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.Accent.dark, lineWidth: isSelected ? 2.5 : 0)
                        }
                        .contextMenu {
                            Button(
                                String.localised("generic.unsubscribe", table: .generic),
                                systemImage: "xmark.circle",
                                role: .destructive
                            ) {
                                send(.unsubscribeTapped(channel))
                            }
                        }
                        .pressable {
                            send(.channelTapped(channel))
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .onAppear {
                            // Anchor on the rendered list: under a filter the
                            // unfiltered list's last channel is never drawn.
                            if channel.id == channels.last?.id {
                                send(.lastItemAppeared)
                            }
                        }
                    }
                }
                .padding()

                if store.isLoadingMore {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .padding()
                }
            }
        }
        .background(Color.Brand.primary)
        .refreshable { send(.pullToRefreshTriggered) }
    }
}
#endif
