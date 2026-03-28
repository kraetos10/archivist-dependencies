#if !os(tvOS)
import AVKit
import Dependencies
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
        PlayerManager.shared.activePlayerViewController = vc
        return vc
    }

    public func updateUIViewController(
        _ uiViewController: AVPlayerViewController,
        context: Context
    ) {
        if uiViewController.player !== PlayerManager.shared.player {
            uiViewController.player = PlayerManager.shared.player
        }
    }

    public func makeCoordinator() -> Coordinator {
        @Dependency(\.pipRestoreService) var pipRestoreService
        return Coordinator(
            onFullscreenDismiss: onFullscreenDismiss,
            pipRestoreRequest: pipRestoreService.request
        )
    }

    public final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        public let onFullscreenDismiss: (() -> Void)?
        private let pipRestoreRequest: @Sendable () async -> Void
        private var isInPiP = false

        public init(
            onFullscreenDismiss: (() -> Void)?,
            pipRestoreRequest: @escaping @Sendable () async -> Void
        ) {
            self.onFullscreenDismiss = onFullscreenDismiss
            self.pipRestoreRequest = pipRestoreRequest
        }

        public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPiP = true
            nonisolated(unsafe) let coordinator = self
            nonisolated(unsafe) let vc = playerViewController
            Task { @MainActor in
                PlayerManager.shared.isInPiP = true
                PlayerManager.shared.activePiPDelegate = coordinator
                PlayerManager.shared.activePlayerViewController = vc
            }
        }

        public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPiP = false
            nonisolated(unsafe) let coordinator = self
            Task { @MainActor in
                // Only clear if we're still the active PiP delegate.
                // If stopPiP() was called programmatically (e.g. mini player tap),
                // the state is already cleared — don't reset it again or we'll
                // interfere with the new video detail that's being set up.
                guard PlayerManager.shared.activePiPDelegate === coordinator else { return }
                PlayerManager.shared.isInPiP = false
                PlayerManager.shared.activePiPDelegate = nil
            }
        }

        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            Task { @MainActor in
                OrientationLock.shared.orientationLock = .landscape
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                    scene.requestGeometryUpdate(prefs)
                }
            }
        }

        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            nonisolated(unsafe) let onDismiss = self.onFullscreenDismiss
            nonisolated(unsafe) let isInPiP = self.isInPiP
            coordinator.animate(alongsideTransition: nil) { @Sendable _ in
                Task { @MainActor in
                    OrientationLock.shared.lockPortrait()
                }
                guard !isInPiP else { return }
                Task { @MainActor in
                    PlayerManager.shared.player?.play()
                }
                onDismiss?()
            }
        }

        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            // Dismiss PiP immediately — the original VC may no longer be in the hierarchy.
            // The mini player will expand to a new video detail with the player still running.
            completionHandler(false)
            let request = pipRestoreRequest
            Task { await request() }
        }
    }
}
#endif
