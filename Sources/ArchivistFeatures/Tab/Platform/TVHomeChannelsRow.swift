#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeChannelsRow: View {
    let channels: [ChannelResponse]
    let serverConfig: ServerConfig
    let focus: FocusState<TVHomeFocus?>.Binding
    let onChannelTapped: (ChannelResponse) -> Void
    let onViewAll: () -> Void

    var body: some View {
        TVHomeSectionContainer(
            title: String.localised("generic.channels", table: .generic),
            icon: "antenna.radiowaves.left.and.right"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                    ForEach(channels) { channel in
                        TVChannelCardView(
                            channel: channel,
                            serverConfig: serverConfig
                        ) {
                            onChannelTapped(channel)
                        }
                        .focused(focus, equals: .card(.channels, id: channel.channelId))
                    }

                    if !channels.isEmpty {
                        TVHomeViewAllCard(style: .channel, action: onViewAll)
                            .focused(focus, equals: .viewAll(.channels))
                    }
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .scrollClipDisabled()
        }
    }
}
#endif
