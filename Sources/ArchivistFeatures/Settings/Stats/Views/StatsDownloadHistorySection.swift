import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct StatsDownloadHistorySection: View {
    let history: [DownloadHistResponse]
    let isExpanded: Bool
    let onToggle: () -> Void

    private var visibleEntries: [DownloadHistResponse] {
        isExpanded ? history : Array(history.prefix(7))
    }

    var body: some View {
        Section {
            ForEach(visibleEntries, id: \.date) { entry in
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.body)
                        .foregroundStyle(Color.Accent.dark)
                        .frame(width: 28)
                    Text(formattedDate(entry.date))
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.primary)
                    Spacer()
                    let count = entry.count ?? 0
                    Text(count > 0 ? "+\(count)" : "-")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(count > 0 ? Color.Text.primary : Color.Brand.secondary)
                }
            }

            if history.count > 7 {
                Button {
                    withAnimation { onToggle() }
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.body)
                            .foregroundStyle(Color.Accent.dark)
                            .frame(width: 28)
                        Text(
                            isExpanded
                                ? String.localised("generic.showLess", table: .generic)
                                : String.localised("generic.showAll \(history.count)", table: .generic)
                        )
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

    private func formattedDate(_ dateString: String?) -> String {
        guard let dateString else { return "" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        return outputFormatter.string(from: date)
    }
}
