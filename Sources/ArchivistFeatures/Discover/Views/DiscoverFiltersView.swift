#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// Sort and filter choices for a search. A popover on iPad, a sheet on
/// iPhone.
struct DiscoverFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var order: YouTubeSearchOrder
    @Binding var duration: YouTubeSearchFilters.Duration
    @Binding var uploaded: YouTubeSearchFilters.Uploaded
    @Binding var hidesShorts: Bool
    let showsVideoFilters: Bool
    let hasActiveFilters: Bool
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String.localised("discover.sort", table: .discover), selection: $order) {
                        ForEach(YouTubeSearchOrder.allCases, id: \.self) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(String.localised("discover.sort", table: .discover))
                } footer: {
                    Text(String.localised("discover.filters.footer", table: .discover))
                }

                Section {
                    Toggle(
                        String.localised("discover.filter.hideShorts", table: .discover),
                        isOn: $hidesShorts
                    )
                }

                if showsVideoFilters {
                    Section(String.localised("discover.filter.duration", table: .discover)) {
                        Picker(
                            String.localised("discover.filter.duration", table: .discover),
                            selection: $duration
                        ) {
                            ForEach(YouTubeSearchFilters.Duration.allCases, id: \.self) { duration in
                                Text(duration.title).tag(duration)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section(String.localised("discover.filter.uploaded", table: .discover)) {
                        Picker(
                            String.localised("discover.filter.uploaded", table: .discover),
                            selection: $uploaded
                        ) {
                            ForEach(YouTubeSearchFilters.Uploaded.allCases, id: \.self) { uploaded in
                                Text(uploaded.title).tag(uploaded)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle(String.localised("discover.filters.title", table: .discover))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String.localised("discover.filters.reset", table: .discover), action: onReset)
                        .disabled(!hasActiveFilters)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String.localised("discover.filters.done", table: .discover)) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .frame(minWidth: 340, minHeight: 480)
    }
}

/// "Sorted by Upload Date · Under 4 minutes", with a way to undo it, so a
/// search that looks short on results explains itself.
struct DiscoverFilterSummary: View {
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(Color.Accent.dark)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(String.localised("discover.filters.clear", table: .discover), action: onClear)
                .font(.footnote.weight(.semibold))
                .tint(Color.Accent.dark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.Surface.highlight, in: Capsule())
    }
}

extension YouTubeSearchFilters.Duration {
    var title: String {
        switch self {
        case .any: String.localised("discover.filter.any", table: .discover)
        case .short: String.localised("discover.filter.duration.short", table: .discover)
        case .medium: String.localised("discover.filter.duration.medium", table: .discover)
        case .long: String.localised("discover.filter.duration.long", table: .discover)
        }
    }
}

extension YouTubeSearchFilters.Uploaded {
    var title: String {
        switch self {
        case .any: String.localised("discover.filter.any", table: .discover)
        case .today: String.localised("discover.filter.uploaded.today", table: .discover)
        case .week: String.localised("discover.filter.uploaded.week", table: .discover)
        case .month: String.localised("discover.filter.uploaded.month", table: .discover)
        case .year: String.localised("discover.filter.uploaded.year", table: .discover)
        }
    }
}

extension YouTubeSearchOrder {
    var title: String {
        switch self {
        case .relevance: String.localised("discover.order.relevance", table: .discover)
        case .date: String.localised("discover.order.date", table: .discover)
        case .viewCount: String.localised("discover.order.viewCount", table: .discover)
        case .rating: String.localised("discover.order.rating", table: .discover)
        }
    }
}
#endif
