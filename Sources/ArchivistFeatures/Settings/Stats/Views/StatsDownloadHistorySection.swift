import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsDownloadHistorySection: View {
    let entries: [DownloadHistResponse]
    let canExpand: Bool
    let isExpanded: Bool
    let toggleTitle: String
    let onToggle: () -> Void

    var body: some View {
        Section {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                StatsFocusableRow {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .font(.body)
                            .foregroundStyle(Color.Accent.dark)
                            .frame(width: StatsFocusableRow<EmptyView>.iconWidth)
                            .accessibilityHidden(true)
                        Text(entry.dateText)
                            .font(.subheadline)
                            .foregroundStyle(Color.Text.primary)
                        Spacer()
                        Text(entry.countText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(entry.hasDownloads ? Color.Text.primary : Color.Brand.secondary)
                    }
                }
            }

            if canExpand {
                Button(action: onToggle) {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.body)
                            .foregroundStyle(Color.Accent.dark)
                            .frame(width: StatsFocusableRow<EmptyView>.iconWidth)
                            .accessibilityHidden(true)
                        Text(toggleTitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.Accent.dark)
                        Spacer()
                    }
                }
            }
        } header: {
            Text(String.localised("settings.downloadHistory", table: .settings))
        }
        .listRowBackground(Color.Surface.highlight)
    }
}
