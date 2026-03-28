#if os(watchOS)
import SwiftUI

public struct WatchSetupRequiredView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.right.inward")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(String(localized: "setup.title", bundle: Bundle.module))
                .font(.headline)

            Text(String(localized: "setup.description", bundle: Bundle.module))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
#endif
