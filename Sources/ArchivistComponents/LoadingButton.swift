import SwiftUI

public struct LoadingButton: View {
    public let title: String
    public let isLoading: Bool
    public let action: () -> Void

    public init(
        title: LocalizedStringResource,
        isLoading: Bool,
        action: @escaping () -> Void
    ) {
        self.title = String(localized: title)
        self.isLoading = isLoading
        self.action = action
    }

    public init(
        title: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(Color.Progress.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Text(title)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.Accent.dark)
    }
}
