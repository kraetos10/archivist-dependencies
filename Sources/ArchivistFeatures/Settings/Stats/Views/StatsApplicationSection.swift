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
                    label: String(localized: "Subscribed Channels"),
                    value: "\(channel.subscribedTrue ?? 0)",
                    icon: "bell"
                )
                StatRowView(
                    label: String(localized: "Active Channels"),
                    value: "\(channel.activeTrue ?? 0)",
                    icon: "checkmark.circle"
                )
                StatRowView(
                    label: String(localized: "Total Channels"),
                    value: "\(channel.docCount ?? 0)",
                    icon: "person.2"
                )
            }
            if let playlist = playlistStats {
                StatRowView(
                    label: String(localized: "Subscribed Playlists"),
                    value: "\(playlist.subscribedTrue ?? 0)",
                    icon: "bell"
                )
                StatRowView(
                    label: String(localized: "Active Playlists"),
                    value: "\(playlist.activeTrue ?? 0)",
                    icon: "checkmark.circle"
                )
                StatRowView(
                    label: String(localized: "Total Playlists"),
                    value: "\(playlist.docCount ?? 0)",
                    icon: "list.bullet.rectangle"
                )
            }
            if let download = downloadStats {
                StatRowView(
                    label: String.localised("video.downloadsPending", table: .videos),
                    value: "\(download.pending ?? 0)",
                    icon: "arrow.down.circle"
                )
                if let videos = download.pendingVideos, videos > 0 {
                    StatRowView(
                        label: String(localized: "  Videos"),
                        value: "\(videos)",
                        icon: "play.rectangle"
                    )
                }
                if let shorts = download.pendingShorts, shorts > 0 {
                    StatRowView(
                        label: String(localized: "  Shorts"),
                        value: "\(shorts)",
                        icon: "bolt.circle"
                    )
                }
                if let streams = download.pendingStreams, streams > 0 {
                    StatRowView(
                        label: String(localized: "  Streams"),
                        value: "\(streams)",
                        icon: "dot.radiowaves.left.and.right"
                    )
                }
            }
        } header: {
            Text(String.localised("settings.application", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
