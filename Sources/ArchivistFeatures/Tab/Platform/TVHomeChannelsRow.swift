#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeChannelsRow: View {
    static let maxItems = 10

    let channels: [ChannelResponse]
    let serverConfig: ServerConfig
    let onChannelTapped: (ChannelResponse) -> Void
    let onViewAll: () -> Void

    var body: some View {
        TVHomeSectionContainer(
            title: String(localized: "Channels"),
            icon: "antenna.radiowaves.left.and.right",
            onViewAll: onViewAll
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(channels.prefix(Self.maxItems)) { channel in
                        TVChannelCardView(
                            channel: channel,
                            serverConfig: serverConfig
                        ) {
                            onChannelTapped(channel)
                        }
                    }

                    if channels.count > 0 {
                        TVHomeViewAllCard(action: onViewAll)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
    }
}
#endif
