#if !os(watchOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Settings section that lets the user pick an app-wide colour theme.
///
/// Self-contained: it owns the persisted `@Shared` selection so it can be
/// dropped into any settings `List` without touching the reducer (the theme
/// is a pure view concern — no reducer logic reads it). The choice is stored
/// under ``AppTheme/storageKey``; `AppView` observes the same key and
/// re-renders the app when it changes.
struct ThemePickerSection: View {
    @Shared(.appStorage(AppTheme.storageKey))
    private var themeRaw = AppTheme.fallback.rawValue

    var body: some View {
        Section {
            Picker(selection: Binding($themeRaw)) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeOptionLabel(theme: theme)
                        .tag(theme.rawValue)
                }
            } label: {
                Text("Theme")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Appearance")
        } footer: {
            Text("Recolours the whole app. Applies right away.")
        }
    }
}

private struct ThemeOptionLabel: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            ThemeSwatch(theme: theme)
            Text(theme.displayName)
                .foregroundStyle(Color.Text.primary)
            Spacer(minLength: 0)
            Image(systemName: theme.symbolName)
                .font(.footnote)
                .foregroundStyle(theme.swatchGradient.last ?? Color.Accent.dark)
        }
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: theme.swatchGradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 40, height: 18)
            .overlay(
                Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }
}
#endif
