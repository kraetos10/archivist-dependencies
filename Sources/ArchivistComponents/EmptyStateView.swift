import SwiftUI

public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let description: String

    public init(
        icon: String,
        title: String,
        description: String
    ) {
        self.icon = icon
        self.title = title
        self.description = description
    }

    public var body: some View {
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 80)
            Image(systemName: icon)
                // Keeps the glyph in proportion as the user scales text; a
                // bare `.system(size: 48)` stays 48pt at every setting.
                .scaledSystemFont(size: 48, relativeTo: .largeTitle)
                .foregroundStyle(Color.Brand.secondary)
                // Decorative — the title and description below carry the
                // meaning, so don't make VoiceOver read out a symbol name.
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}
