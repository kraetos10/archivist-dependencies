#if !os(watchOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Settings section that lets the user pick an app-wide colour theme.
///
/// Self-contained: it owns the persisted `@Shared` selection so it can be
/// dropped into any settings `List` without touching the reducer (the theme
/// is a pure view concern — no reducer logic reads it). The choice is stored
/// under the typed `.selectedAppTheme` key; `AppView` observes it and
/// re-renders the app when it changes.
struct ThemePickerSection: View {
    @Shared(.selectedAppTheme) private var theme

    var body: some View {
        Section {
            Picker(selection: Binding($theme)) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeOptionLabel(theme: theme)
                        .tag(theme)
                }
            } label: {
                Text(String.localised("settings.theme", table: .settings))
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text(String.localised("settings.appearance", table: .settings))
        } footer: {
            Text(String.localised("settings.theme.footer", table: .settings))
        }
    }
}

private struct ThemeOptionLabel: View {
    let theme: AppTheme

    /// Footnote is 23pt on tvOS, too small to read at 10ft.
    private static var iconFont: Font {
        #if os(tvOS)
        .subheadline
        #else
        .footnote
        #endif
    }

    var body: some View {
        HStack(spacing: 12) {
            ThemeSwatch(theme: theme)
            Text(theme.displayName)
                .foregroundStyle(Color.Text.primary)
            Spacer(minLength: 0)
            Image(systemName: theme.symbolName)
                .font(Self.iconFont)
                // Decorative: the theme name beside it carries the meaning.
                .accessibilityHidden(true)
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
            .overlay {
                Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
    }
}
#endif
