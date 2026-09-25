#if os(tvOS)
import SwiftUI

/// Base style for tvOS cards. The focus treatment lives on the card's
/// artwork (`tvCardFocusEffect`), so this only dims on press.
public struct TVCardButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

/// Capsule chip for tvOS filter and sort controls. The style owns the
/// colours so focus reads clearly at 10ft: focused is a white fill with
/// dark text (the system convention), selected is the inverted brand chip,
/// anything else sits on the highlight surface.
public struct TVCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    private let isSelected: Bool

    public init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.medium)
            .foregroundStyle(foreground)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(background, in: Capsule())
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? 0.4 : 0),
                radius: isFocused ? 12 : 0,
                y: isFocused ? 8 : 0
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private var foreground: Color {
        if isFocused { return .black }
        return isSelected ? Color.Brand.primary : Color.Text.primary
    }

    private var background: Color {
        if isFocused { return .white }
        return isSelected ? Color.Text.primary : Color.Surface.highlight
    }
}
#endif
