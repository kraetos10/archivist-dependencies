import ArchivistComponents
import SwiftUI

struct StatRowView: View {
    let label: String
    let value: String
    let icon: String
    /// A breakdown row under the one above it.
    var isIndented = false

    var body: some View {
        StatsFocusableRow {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.Accent.dark)
                    .frame(width: StatsFocusableRow<EmptyView>.iconWidth)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
            }
            .padding(.leading, isIndented ? 16 : 0)
        }
    }
}

/// A read-only stats row. On tvOS the focus engine only scrolls to things
/// that can take focus, so every row — not just some — is a no-op button
/// there; otherwise the list stops scrolling at the last focusable row.
struct StatsFocusableRow<Content: View>: View {
    /// Width of a row's leading icon column. tvOS icons render far wider
    /// than iOS ones, so a shared iOS-sized column pushes some labels right.
    static var iconWidth: CGFloat {
        #if os(tvOS)
        48
        #else
        28
        #endif
    }

    @ViewBuilder let content: Content

    var body: some View {
        #if os(tvOS)
        Button {} label: {
            content
        }
        .buttonStyle(.plain)
        #else
        content
        #endif
    }
}
