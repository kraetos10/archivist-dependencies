#if os(iOS)
import SwiftUI
import UIKit

/// Renders the live VLC video feed into a small drawable view.
/// Used by the mini player when the active backend is VLC.
struct MiniVLCPlayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let vlcBackend = PlayerManager.shared.backend as? VLCPlayerBackend else {
            return
        }
        if vlcBackend.mediaPlayer.drawable as? UIView !== uiView {
            vlcBackend.attachDrawable(uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Release the drawable so VLC doesn't hold a reference to a dead view.
        if let vlcBackend = PlayerManager.shared.backend as? VLCPlayerBackend,
           vlcBackend.mediaPlayer.drawable as? UIView === uiView {
            vlcBackend.mediaPlayer.drawable = nil
        }
    }
}
#endif
