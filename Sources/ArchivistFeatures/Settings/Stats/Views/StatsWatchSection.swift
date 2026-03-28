import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsWatchSection: View {
    let watch: WatchStatsResponse

    var body: some View {
        let total = (watch.watched ?? 0) + (watch.unwatched ?? 0)
        let watchedPct = total > 0 ? Double(watch.watched ?? 0) / Double(total) * 100 : 0
        let unwatchedPct = total > 0 ? Double(watch.unwatched ?? 0) / Double(total) * 100 : 0

        Section {
            StatRowView(
                label: String.localised("video.watched", table: .videos),
                value: "\(watch.watched ?? 0) (\(String(format: "%.1f", watchedPct))%)",
                icon: "eye"
            )
            StatRowView(
                label: String.localised("video.unwatched", table: .videos),
                value: "\(watch.unwatched ?? 0) (\(String(format: "%.1f", unwatchedPct))%)",
                icon: "eye.slash"
            )
            if let continueWatching = watch.continueWatching, continueWatching > 0 {
                StatRowView(
                    label: String(localized: "Continue Watching"),
                    value: "\(continueWatching)",
                    icon: "play.circle"
                )
            }
        } header: {
            Text(String.localised("video.watchProgress", table: .videos))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
