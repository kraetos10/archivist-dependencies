import SwiftUI

public struct PlayNextTransitionModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
    }
}

extension View {
    public func playNextTransition() -> some View {
        modifier(PlayNextTransitionModifier())
    }
}
