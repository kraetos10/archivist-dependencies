import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsVideoTypeSection: View {
    let video: VideoStatsResponse

    var body: some View {
        Section {
            StatRowView(
                label: String.localised("video.typeRegular", table: .videos),
                value: "\(video.typeVideos ?? 0)",
                icon: "play.rectangle"
            )
            StatRowView(
                label: String.localised("video.typeShorts", table: .videos),
                value: "\(video.typeShorts ?? 0)",
                icon: "bolt.circle"
            )
            StatRowView(
                label: String.localised("video.typeStreams", table: .videos),
                value: "\(video.typeStreams ?? 0)",
                icon: "dot.radiowaves.left.and.right"
            )
        } header: {
            Text(String.localised("video.videoType", table: .videos))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
