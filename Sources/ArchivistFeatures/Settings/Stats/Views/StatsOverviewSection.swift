import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsOverviewSection: View {
    let video: VideoStatsResponse

    var body: some View {
        Section {
            StatRowView(
                label: String.localised("video.totalVideos", table: .videos),
                value: "\(video.docCount ?? 0)",
                icon: "film.stack"
            )
            StatRowView(
                label: String(localized: "Media Size"),
                value: formatBytes(video.totalSize),
                icon: "internaldrive"
            )
            StatRowView(
                label: String(localized: "Duration"),
                value: formatDuration(video.totalDuration),
                icon: "clock"
            )
            StatRowView(
                label: String.localised("generic.active", table: .generic),
                value: "\(video.activeTrue ?? 0)",
                icon: "checkmark.circle"
            )
            StatRowView(
                label: String.localised("generic.inactive", table: .generic),
                value: "\(video.activeFalse ?? 0)",
                icon: "xmark.circle"
            )
        } header: {
            Text(String.localised("generic.overview", table: .generic))
        }
        .listRowBackground(Color.Surface.highlight)
    }

    private func formatBytes(_ bytes: Int?) -> String {
        guard let bytes else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDuration(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "NA" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: TimeInterval(seconds)) ?? "NA"
    }
}
