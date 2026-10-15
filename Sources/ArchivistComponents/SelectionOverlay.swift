import SwiftUI

/// Outline and check mark over a card while picking several.
public struct SelectionOverlay: View {
    let isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isSelected ? Color.Accent.dark : .clear, lineWidth: 3)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .scaledSystemFont(size: 24, relativeTo: .title2)
                    .foregroundStyle(isSelected ? Color.Accent.dark : Color.Text.primary)
                    .background(Circle().fill(Color.Surface.highlight))
                    .padding(12)
                    .accessibilityHidden(true)
            }
    }
}
