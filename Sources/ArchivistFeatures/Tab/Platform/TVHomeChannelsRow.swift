#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeChannelsRow: View {
    let channels: [ChannelResponse]
    let serverConfig: ServerConfig
    let onChannelTapped: (ChannelResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Channels"))
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(channels) { channel in
                        TVChannelCardView(
                            channel: channel,
                            serverConfig: serverConfig
                        ) {
                            onChannelTapped(channel)
                        }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}
#endif
