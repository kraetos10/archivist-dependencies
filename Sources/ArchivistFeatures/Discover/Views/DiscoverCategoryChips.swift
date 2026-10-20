#if !os(tvOS)
import ArchivistComponents
import SwiftUI

/// "All" and YouTube's categories, for narrowing Trending.
struct DiscoverCategoryChips: View {
    let selected: DiscoverCategory?
    let onSelect: (DiscoverCategory?) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(
                    title: String.localised("discover.category.all", table: .discover),
                    isSelected: selected == nil
                ) {
                    onSelect(nil)
                }
                ForEach(DiscoverCategory.allCases) { category in
                    chip(title: category.title, isSelected: selected == category) {
                        onSelect(category)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    private func chip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.Text.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.Accent.dark : Color.Surface.highlight,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
