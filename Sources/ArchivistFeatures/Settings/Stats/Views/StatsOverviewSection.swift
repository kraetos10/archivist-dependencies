import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsOverviewSection: View {
    let video: VideoStatsResponse

    var body: some View {
        Section {
            StatRowView(
                label: String.localised("video.totalVideos", table: .videos),
                value: (video.docCount ?? 0).formatted(),
                icon: "film.stack"
            )
            StatRowView(
                label: String.localised("stats.mediaSize", table: .settings),
                value: video.mediaSizeText,
                icon: "internaldrive"
            )
            StatRowView(
                label: String.localised("stats.duration", table: .settings),
                value: video.durationText,
                icon: "clock"
            )
            StatRowView(
                label: String.localised("generic.active", table: .generic),
                value: (video.activeTrue ?? 0).formatted(),
                icon: "checkmark.circle"
            )
            StatRowView(
                label: String.localised("generic.inactive", table: .generic),
                value: (video.activeFalse ?? 0).formatted(),
                icon: "xmark.circle"
            )
        } header: {
            Text(String.localised("generic.overview", table: .generic))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
