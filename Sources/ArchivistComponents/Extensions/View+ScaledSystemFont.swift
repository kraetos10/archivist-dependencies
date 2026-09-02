import SwiftUI

public extension View {
    /// A system font at a fixed point size that still responds to Dynamic
    /// Type.
    ///
    /// `Font.system(size:)` is frozen at whatever size it's given — an icon
    /// set that way stays 48pt from xSmall through to AX5, which is what
    /// makes large glyph + caption layouts look wrong at accessibility
    /// sizes. There's no `relativeTo:` on the system font (that parameter
    /// only exists on `Font.custom`), so scaling has to come from
    /// `@ScaledMetric`, which is what this wraps.
    ///
    /// - Parameters:
    ///   - size: The point size at the default Dynamic Type setting.
    ///   - style: The text style the size scales in step with.
    ///   - weight: Font weight, unchanged by scaling.
    func scaledSystemFont(
        size: CGFloat,
        relativeTo style: Font.TextStyle,
        weight: Font.Weight = .regular
    ) -> some View {
        modifier(ScaledSystemFont(size: size, style: style, weight: weight))
    }
}

private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, style: Font.TextStyle, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}
