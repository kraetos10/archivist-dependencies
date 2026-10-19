#if !os(tvOS)
import ArchivistComponents
import SwiftUI

/// The gear in Home's toolbar that opens Settings. The dot says the server
/// is busy, which used to be the Settings tab's badge.
struct HomeSettingsButton: View {
    let hasActivity: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .overlay(alignment: .topTrailing) {
                    if hasActivity {
                        Circle()
                            .fill(Color.Accent.dark)
                            .frame(width: 9, height: 9)
                            .offset(x: 3, y: -3)
                            .accessibilityHidden(true)
                    }
                }
        }
        .accessibilityLabel(String.localised("generic.settings", table: .generic))
        .accessibilityValue(
            hasActivity ? String.localised("settings.activeTasks", table: .settings) : ""
        )
    }
}
#endif
