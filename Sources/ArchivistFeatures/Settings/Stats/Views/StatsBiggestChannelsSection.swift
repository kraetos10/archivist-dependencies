import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsBiggestChannelsSection: View {
    let channels: [BiggestChannelResponse]
    let serverConfig: ServerConfig

    var body: some View {
        Section {
            ForEach(channels) { channel in
                StatsFocusableRow {
                    HStack(spacing: 12) {
                        ChannelThumbView(
                            url: channel.thumbnailURL(config: serverConfig),
                            size: 32
                        )
                        .frame(width: StatsFocusableRow<EmptyView>.iconWidth)
                        .accessibilityHidden(true)
                        Text(channel.name ?? "")
                            .font(.subheadline)
                            .foregroundStyle(Color.Text.primary)
                        Spacer()
                        Text(channel.videoCountText)
                            .font(.caption)
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
            }
        } header: {
            Text(String.localised("settings.biggestChannels", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
