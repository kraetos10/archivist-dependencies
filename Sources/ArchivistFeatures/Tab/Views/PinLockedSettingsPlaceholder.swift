#if !os(tvOS)
import ArchivistComponents
import SwiftUI

/// Shown in place of Settings while child mode keeps it locked.
struct PinLockedSettingsPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .scaledSystemFont(size: 40, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(Color.Accent.dark)
            Text(String.localised("childMode.pinEntry.subtitle", table: .login))
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Brand.primary)
    }
}
#endif
