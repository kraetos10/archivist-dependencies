#if os(tvOS)
import SwiftUI
import UIKit

/// Captures raw UIPress events from the Siri Remote. Left/Right go through
/// hold detection: a quick press dispatches `onTap`, one still down after
/// `holdThreshold` dispatches `onHoldBegan` and a matching `onHoldEnded` on
/// release. Every other press dispatches `onTap` on release, however long
/// it was held. A pan on the touch surface drives the `onScrub*` callbacks.
struct TVPlayerPressView: UIViewRepresentable {
    let onTap: (UIPress.PressType) -> Void
    let onHoldBegan: (UIPress.PressType) -> Void
    let onHoldEnded: (UIPress.PressType) -> Void
    let onScrubBegan: () -> Void
    let onScrubChanged: (CGFloat) -> Void
    let onScrubEnded: (Bool) -> Void

    func makeUIView(context: Context) -> TVPressTrackingView {
        let view = TVPressTrackingView()
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: TVPressTrackingView, context: Context) {
        apply(to: uiView)
    }

    private func apply(to view: TVPressTrackingView) {
        view.onTap = onTap
        view.onHoldBegan = onHoldBegan
        view.onHoldEnded = onHoldEnded
        view.onScrubBegan = onScrubBegan
        view.onScrubChanged = onScrubChanged
        view.onScrubEnded = onScrubEnded
    }
}
#endif
