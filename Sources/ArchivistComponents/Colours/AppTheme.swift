import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A user-selectable colour theme. `forest` is the original green/teal
/// brand; every other case re-tints all of the semantic colour tokens in
/// `SemanticTokens.swift`.
///
/// The active theme is persisted in `UserDefaults.standard` under
/// ``storageKey`` — the same store `@Shared(.appStorage:)` writes to — so
/// the token getters can resolve the current palette live, and a change
/// made through a `@Shared` binding is seen immediately here.
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    /// Original green/teal brand.
    case forest
    /// Cool blues.
    case ocean
    /// Warm coral / sunset.
    case sunset
    /// Rich purples.
    case amethyst

    public var id: String { rawValue }

    /// UserDefaults key that stores the selected theme's `rawValue`.
    public static let storageKey = "selectedAppTheme"

    /// Fallback used before the user has ever picked a theme.
    public static let fallback = AppTheme.forest

    /// The currently-selected theme, read live from `UserDefaults.standard`.
    /// Backed by CoreFoundation's in-memory preferences cache, so this is a
    /// cheap lookup even though the semantic-colour getters call it often.
    public static var current: AppTheme {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        return raw.flatMap(AppTheme.init(rawValue:)) ?? fallback
    }

    /// User-facing name shown in the theme picker.
    public var displayName: String {
        switch self {
        case .forest: return "Forest"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .amethyst: return "Amethyst"
        }
    }

    /// SF Symbol shown alongside the name in the picker.
    public var symbolName: String {
        switch self {
        case .forest: return "leaf.fill"
        case .ocean: return "drop.fill"
        case .sunset: return "sun.horizon.fill"
        case .amethyst: return "sparkles"
        }
    }

    // MARK: - Token resolution

    /// Resolve a semantic token to a light/dark-aware `Color` for this theme.
    /// On iOS/tvOS the returned colour tracks the active `UITraitCollection`
    /// so it flips with the system appearance; elsewhere it resolves to the
    /// light value (the Colours layer isn't used on watchOS).
    public func color(_ keyPath: KeyPath<ThemePalette, ThemePalette.Pair>) -> Color {
        let pair = palette[keyPath: keyPath]
        #if os(iOS) || os(tvOS)
        return Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? pair.dark : pair.light
            return UIColor(
                red: rgb.red,
                green: rgb.green,
                blue: rgb.blue,
                alpha: rgb.opacity
            )
        })
        #else
        return Self.staticColor(pair.light)
        #endif
    }

    /// A flat `Color` for one RGB triple, used for the picker swatches so a
    /// theme's own colours preview regardless of which theme is active.
    static func staticColor(_ rgb: ThemePalette.RGB) -> Color {
        Color(
            .sRGB,
            red: rgb.red,
            green: rgb.green,
            blue: rgb.blue,
            opacity: rgb.opacity
        )
    }

    /// Two signature colours (light-mode values) for the picker's swatch
    /// gradient — a brighter accent fading into its deeper companion.
    public var swatchGradient: [Color] {
        [
            Self.staticColor(palette.brandSecondary.light),
            Self.staticColor(palette.accentDark.light),
        ]
    }
}

/// Light/dark values for every themeable semantic token. `fontPrimary`
/// (body text) is intentionally absent — it stays neutral across themes and
/// remains asset-catalog backed in `SemanticTokens.swift`.
public struct ThemePalette: Sendable {
    public struct RGB: Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let opacity: Double

        public init(
            _ red: Double,
            _ green: Double,
            _ blue: Double,
            _ opacity: Double = 1
        ) {
            self.red = red
            self.green = green
            self.blue = blue
            self.opacity = opacity
        }
    }

    public struct Pair: Sendable {
        public let light: RGB
        public let dark: RGB

        public init(light: RGB, dark: RGB) {
            self.light = light
            self.dark = dark
        }
    }

    /// App background (near-white in light, deeply tinted near-black in dark).
    public let brandPrimary: Pair
    /// Primary brand accent hue.
    public let brandSecondary: Pair
    /// Progress-bar fill.
    public let progressTint: Pair
    /// Deeper accent used for icons and emphasis.
    public let accentDark: Pair
    /// Highlighted surface / card background.
    public let highlightBG: Pair
}

extension AppTheme {
    public var palette: ThemePalette {
        switch self {
        case .forest:
            // Original brand values — unchanged so existing installs look
            // identical until the user opts into another theme.
            return ThemePalette(
                brandPrimary: .init(
                    light: .init(0.941, 0.957, 0.965),
                    dark: .init(0.000, 0.125, 0.184)
                ),
                brandSecondary: .init(
                    light: .init(0.145, 0.580, 0.522),
                    dark: .init(0.592, 0.831, 0.784)
                ),
                progressTint: .init(
                    light: .init(1.000, 1.000, 1.000),
                    dark: .init(0.592, 0.831, 0.784)
                ),
                accentDark: .init(
                    light: .init(0.114, 0.478, 0.427),
                    dark: .init(0.145, 0.580, 0.522)
                ),
                highlightBG: .init(
                    light: .init(0.910, 0.957, 0.945),
                    dark: .init(0.000, 0.161, 0.231)
                )
            )
        case .ocean:
            return ThemePalette(
                brandPrimary: .init(
                    light: .init(0.937, 0.953, 0.969),
                    dark: .init(0.000, 0.086, 0.157)
                ),
                brandSecondary: .init(
                    light: .init(0.129, 0.435, 0.769),
                    dark: .init(0.545, 0.741, 0.965)
                ),
                progressTint: .init(
                    light: .init(1.000, 1.000, 1.000),
                    dark: .init(0.545, 0.741, 0.965)
                ),
                accentDark: .init(
                    light: .init(0.098, 0.353, 0.639),
                    dark: .init(0.176, 0.494, 0.816)
                ),
                highlightBG: .init(
                    light: .init(0.902, 0.933, 0.973),
                    dark: .init(0.000, 0.114, 0.208)
                )
            )
        case .sunset:
            return ThemePalette(
                brandPrimary: .init(
                    light: .init(0.984, 0.957, 0.941),
                    dark: .init(0.129, 0.043, 0.063)
                ),
                brandSecondary: .init(
                    light: .init(0.851, 0.325, 0.310),
                    dark: .init(0.973, 0.635, 0.525)
                ),
                progressTint: .init(
                    light: .init(1.000, 1.000, 1.000),
                    dark: .init(0.973, 0.635, 0.525)
                ),
                accentDark: .init(
                    light: .init(0.702, 0.216, 0.259),
                    dark: .init(0.902, 0.435, 0.404)
                ),
                highlightBG: .init(
                    light: .init(0.988, 0.925, 0.906),
                    dark: .init(0.180, 0.063, 0.086)
                )
            )
        case .amethyst:
            return ThemePalette(
                brandPrimary: .init(
                    light: .init(0.961, 0.953, 0.980),
                    dark: .init(0.063, 0.031, 0.125)
                ),
                brandSecondary: .init(
                    light: .init(0.478, 0.298, 0.816),
                    dark: .init(0.749, 0.659, 0.976)
                ),
                progressTint: .init(
                    light: .init(1.000, 1.000, 1.000),
                    dark: .init(0.749, 0.659, 0.976)
                ),
                accentDark: .init(
                    light: .init(0.361, 0.204, 0.639),
                    dark: .init(0.561, 0.404, 0.898)
                ),
                highlightBG: .init(
                    light: .init(0.945, 0.929, 0.984),
                    dark: .init(0.098, 0.051, 0.180)
                )
            )
        }
    }
}
