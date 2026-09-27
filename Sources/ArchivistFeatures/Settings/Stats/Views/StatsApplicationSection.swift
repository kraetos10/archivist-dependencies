import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsApplicationSection: View {
    let channelStats: ChannelStatsResponse?
    let playlistStats: PlaylistStatsResponse?
    let downloadStats: DownloadStatsResponse?

    var body: some View {
        Section {
            if let channel = channelStats {
                StatRowView(
                    label: String.localised("stats.subscribedChannels", table: .settings),
                    value: (channel.subscribedTrue ?? 0).formatted(),
                    icon: "bell"
                )
                StatRowView(
                    label: String.localised("stats.activeChannels", table: .settings),
                    value: (channel.activeTrue ?? 0).formatted(),
                    icon: "checkmark.circle"
                )
                StatRowView(
                    label: String.localised("stats.totalChannels", table: .settings),
                    value: (channel.docCount ?? 0).formatted(),
                    icon: "person.2"
                )
            }
            if let playlist = playlistStats {
                StatRowView(
                    label: String.localised("stats.subscribedPlaylists", table: .settings),
                    value: (playlist.subscribedTrue ?? 0).formatted(),
                    icon: "bell"
                )
                StatRowView(
                    label: String.localised("stats.activePlaylists", table: .settings),
                    value: (playlist.activeTrue ?? 0).formatted(),
                    icon: "checkmark.circle"
                )
                StatRowView(
                    label: String.localised("stats.totalPlaylists", table: .settings),
                    value: (playlist.docCount ?? 0).formatted(),
                    icon: "list.bullet.rectangle"
                )
            }
            if let download = downloadStats {
                StatRowView(
                    label: String.localised("video.downloadsPending", table: .videos),
                    value: (download.pending ?? 0).formatted(),
                    icon: "arrow.down.circle"
                )
                if let videos = download.pendingVideos, videos > 0 {
                    StatRowView(
                        label: String.localised("stats.pendingVideos", table: .settings),
                        value: videos.formatted(),
                        icon: "play.rectangle",
                        isIndented: true
                    )
                }
                if let shorts = download.pendingShorts, shorts > 0 {
                    StatRowView(
                        label: String.localised("stats.pendingShorts", table: .settings),
                        value: shorts.formatted(),
                        icon: "bolt.circle",
                        isIndented: true
                    )
                }
                if let streams = download.pendingStreams, streams > 0 {
                    StatRowView(
                        label: String.localised("stats.pendingStreams", table: .settings),
                        value: streams.formatted(),
                        icon: "dot.radiowaves.left.and.right",
                        isIndented: true
                    )
                }
            }
        } header: {
            Text(String.localised("settings.application", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
