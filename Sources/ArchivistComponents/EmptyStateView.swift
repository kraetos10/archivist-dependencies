import SwiftUI

public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let description: String

    public init(icon: String, title: String, description: String) {
        self.icon = icon
        self.title = title
        self.description = description
    }

    public var body: some View {
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 80)
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.Brand.secondary)
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
