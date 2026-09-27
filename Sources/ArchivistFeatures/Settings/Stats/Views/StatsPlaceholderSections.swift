import ArchivistComponents
import SwiftUI

struct StatsPlaceholderOverviewSection: View {
    var body: some View {
        Section {
            StatRowView(label: String.localised("video.totalVideos", table: .videos), value: "0000", icon: "film.stack")
            StatRowView(label: String.localised("stats.mediaSize", table: .settings), value: "00.0 GB", icon: "internaldrive")
            StatRowView(label: String.localised("stats.duration", table: .settings), value: "000h 00m", icon: "clock")
            StatRowView(
                label: String.localised("generic.active", table: .generic),
                value: "000",
                icon: "checkmark.circle"
            )
            StatRowView(
                label: String.localised("generic.inactive", table: .generic),
                value: "000",
                icon: "xmark.circle"
            )
        } header: {
            Text(String.localised("generic.overview", table: .generic))
        }
        .listRowBackground(Color.Surface.highlight)
        .redacted(reason: .placeholder)
    }
}

struct StatsPlaceholderApplicationSection: View {
    var body: some View {
        Section {
            StatRowView(label: String.localised("generic.channels", table: .generic), value: "000", icon: "person.2")
            StatRowView(label: String.localised("stats.subscribed", table: .settings), value: "000", icon: "bell")
            StatRowView(
                label: String.localised("generic.playlists", table: .generic),
                value: "000",
                icon: "list.bullet.rectangle"
            )
            StatRowView(
                label: String.localised("video.downloadsPending", table: .videos),
                value: "000",
                icon: "arrow.down.circle"
            )
        } header: {
            Text(String.localised("settings.application", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
        .redacted(reason: .placeholder)
    }
}
