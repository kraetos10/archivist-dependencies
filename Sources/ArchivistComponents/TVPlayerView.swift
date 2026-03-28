#if os(tvOS)
import AVKit
import SwiftUI

public struct TVPlayerView: UIViewControllerRepresentable {
    public var onDismiss: (() -> Void)?

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = PlayerManager.shared.player
        vc.delegate = context.coordinator
        return vc
    }

    public func updateUIViewController(
        _ uiViewController: AVPlayerViewController,
        context: Context
    ) {
        uiViewController.player = PlayerManager.shared.player
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    public final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        public let onDismiss: (() -> Void)?

        public init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }

        public func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
            true
        }

        public func playerViewControllerDidEndDismissalTransition(_ playerViewController: AVPlayerViewController) {
            onDismiss?()
        }
    }
}
#endif
