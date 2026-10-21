import SwiftUI

/// A soft highlight sweeping across a placeholder, to say "loading" more
/// gently than a spinner. The highlight is clipped to the view's own shape,
/// so give it solid placeholder fills. With Reduce Motion on it holds still.
public struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let period: TimeInterval = 1.4

    public init() {}

    public func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let phase = time.truncatingRemainder(dividingBy: Self.period) / Self.period
                    GeometryReader { proxy in
                        let band = proxy.size.width * 0.6
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.28), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: band)
                        .offset(x: -band + (proxy.size.width + band) * phase)
                    }
                }
                .mask(content)
                .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }
}

public extension View {
    /// Sweeps a highlight across a placeholder while content loads.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
