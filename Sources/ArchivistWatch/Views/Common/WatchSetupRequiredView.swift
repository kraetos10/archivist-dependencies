#if os(watchOS)
import SwiftUI

public struct WatchSetupRequiredView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.right.inward")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(String(localized: "setup.title", bundle: .module))
                .font(.headline)

            Text(String(localized: "setup.description", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
#endif
