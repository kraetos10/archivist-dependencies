#if !os(tvOS)
import AVKit
import SwiftUI

public struct AVPlayerViewControllerWrapper: UIViewControllerRepresentable {
    public var onFullscreenDismiss: (() -> Void)?

    public init(onFullscreenDismiss: (() -> Void)? = nil) {
        self.onFullscreenDismiss = onFullscreenDismiss
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = PlayerManager.shared.player
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.delegate = context.coordinator
        return vc
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = PlayerManager.shared.player
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onFullscreenDismiss: onFullscreenDismiss)
    }

    public final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        public let onFullscreenDismiss: (() -> Void)?
        private var isInPiP = false

        public init(onFullscreenDismiss: (() -> Void)?) {
            self.onFullscreenDismiss = onFullscreenDismiss
        }

        public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPiP = true
        }

        public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPiP = false
        }

        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            nonisolated(unsafe) let onDismiss = self.onFullscreenDismiss
            nonisolated(unsafe) let isInPiP = self.isInPiP
            coordinator.animate(alongsideTransition: nil) { @Sendable _ in
                guard !isInPiP else { return }
                onDismiss?()
            }
        }

        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            NotificationCenter.default.post(name: .pipRestoreRequested, object: nil)
            completionHandler(true)
        }
    }
}
#endif
