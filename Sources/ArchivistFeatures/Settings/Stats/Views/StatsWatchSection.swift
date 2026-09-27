import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsWatchSection: View {
    let watch: WatchStatsResponse

    var body: some View {
        Section {
            StatRowView(
                label: String.localised("video.watched", table: .videos),
                value: watch.watchedText,
                icon: "eye"
            )
            StatRowView(
                label: String.localised("video.unwatched", table: .videos),
                value: watch.unwatchedText,
                icon: "eye.slash"
            )
            if let continueWatching = watch.continueWatching, continueWatching > 0 {
                StatRowView(
                    label: String.localised("video.continueWatching", table: .videos),
                    value: continueWatching.formatted(),
                    icon: "play.circle"
                )
            }
        } header: {
            Text(String.localised("video.watchProgress", table: .videos))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
