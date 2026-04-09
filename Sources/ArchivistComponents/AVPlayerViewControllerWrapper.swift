#if !os(tvOS)
import AVKit
import Dependencies
import SwiftUI

/// Creates a fresh `AVPlayerViewController` bound to the shared `AVPlayer`
/// owned by `PlayerManager`. SwiftUI manages the VC's lifecycle directly —
/// no reparenting, no persistent surface. Reparenting a single persistent
/// VC between hosts was the cause of pause/play glitches and the video
/// dropping its display when the app backgrounded or another app came
/// forward on iPad. The trade-off is a brief black frame during the
/// mini ↔ full transition, which is acceptable.
public struct AVPlayerViewControllerWrapper: UIViewControllerRepresentable {
    public var showsPlaybackControls: Bool

    public init(
        role: PlayerSurfaceRole = .fullDetail,
        showsPlaybackControls: Bool = true
    ) {
        // `role` is accepted for source compatibility with call sites that
        // still pass it (e.g. the mini player). AVPlayer doesn't need the
        // role gate because each host creates its own VC.
        _ = role
        self.showsPlaybackControls = showsPlaybackControls
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = PlayerManager.shared.player
        vc.showsPlaybackControls = showsPlaybackControls
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
        uiViewController.showsPlaybackControls = showsPlaybackControls
    }

    public func makeCoordinator() -> Coordinator {
        @Dependency(\.pipRestoreService) var pipRestoreService
        return Coordinator(
            pipRestoreRequest: pipRestoreService.request
        )
    }

    public final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        private let pipRestoreRequest: @Sendable () async -> Void
        private var isInPiP = false

        public init(
            pipRestoreRequest: @escaping @Sendable () async -> Void
        ) {
            self.pipRestoreRequest = pipRestoreRequest
        }

        public func playerViewControllerWillStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            isInPiP = true
            nonisolated(unsafe) let coordinator = self
            nonisolated(unsafe) let vc = playerViewController
            Task { @MainActor in
                PlayerManager.shared.isInPiP = true
                PlayerManager.shared.activePiPDelegate = coordinator
                PlayerManager.shared.activePlayerViewController = vc
                PlayerManager.shared.onPiPStartRequested?()
            }
        }

        public func playerViewControllerDidStopPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            isInPiP = false
            nonisolated(unsafe) let coordinator = self
            Task { @MainActor in
                // Only clear if we're still the active PiP delegate —
                // programmatic stopPiP() may have already cleared it.
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
                OrientationLock.shared.unlock()
            }
        }

        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            nonisolated(unsafe) let isInPiP = self.isInPiP
            coordinator.animate(alongsideTransition: nil) { @Sendable _ in
                Task { @MainActor in
                    OrientationLock.shared.lockPortrait()
                    // AVPlayerViewController pauses on fullscreen exit; resume
                    // unless PiP is active, which owns playback in its own window.
                    guard !isInPiP else { return }
                    PlayerManager.shared.player?.play()
                }
            }
        }

        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            // Dismiss PiP immediately — the original VC may no longer exist.
            // The mini player / restore flow will expand to a fresh video
            // detail with the player still running.
            completionHandler(false)
            let request = pipRestoreRequest
            Task { await request() }
        }
    }
}
#endif
