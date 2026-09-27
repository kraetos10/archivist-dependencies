#if os(tvOS)
import SwiftUI

/// Hosts `TVVLCPlayerHostView` in the tvOS player.
struct TVVLCVideoRenderView: UIViewRepresentable {
    func makeUIView(context: Context) -> TVVLCPlayerHostView {
        let view = TVVLCPlayerHostView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: TVVLCPlayerHostView, context: Context) {
        uiView.adoptPlayerView()
    }

    static func dismantleUIView(_ uiView: TVVLCPlayerHostView, coordinator: ()) {
        uiView.detachPlayerView()
    }
}
#endif
