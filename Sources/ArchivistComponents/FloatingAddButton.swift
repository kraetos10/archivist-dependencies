import SwiftUI

public struct FloatingAddButton: View {
    public let accessibilityLabel: String
    public let action: () -> Void

    /// - Parameter accessibilityLabel: What VoiceOver announces for the
    ///   icon-only button. Defaults to a generic "Add"; pass something
    ///   specific ("Add Video") where the context allows.
    public init(
        accessibilityLabel: String = String.localised("generic.add", table: .generic),
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        HStack {
            Spacer()
            button
                .padding(.trailing, 24)
                .padding(.bottom, 8)
        }
    }

    public var button: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.Accent.dark)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
