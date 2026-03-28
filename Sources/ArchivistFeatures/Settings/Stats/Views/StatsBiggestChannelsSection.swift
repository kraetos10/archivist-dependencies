import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsBiggestChannelsSection: View {
    let channels: [BiggestChannelResponse]
    let serverConfig: ServerConfig

    var body: some View {
        Section {
            ForEach(channels) { channel in
                HStack(spacing: 12) {
                    ChannelThumbView(
                        url: channelThumbURL(for: channel.id),
                        size: 32
                    )
                    Text(channel.name ?? "")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)
                    Spacer()
                    Text("\(channel.docCount ?? 0) videos")
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }
        } header: {
            Text(String.localised("settings.biggestChannels", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
    }

    private func channelThumbURL(for channelId: String?) -> URL? {
        guard let channelId else { return nil }
        return serverConfig.fullURL(for: "/cache/channels/\(channelId)_thumb.jpg")
    }
}
