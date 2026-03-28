#if !os(tvOS)
import AVKit
import SwiftUI

/// A lightweight `AVPlayerViewController` host that renders the shared
/// `PlayerManager.shared.player` without transport controls. Used by
/// the mini player to show the live video in a small frame.
struct MiniAVPlayerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = PlayerManager.shared.player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        vc.allowsPictureInPicturePlayback = false
        return vc
    }

    func updateUIViewController(
        _ uiViewController: AVPlayerViewController,
        context: Context
    ) {
        if uiViewController.player !== PlayerManager.shared.player {
            uiViewController.player = PlayerManager.shared.player
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: AVPlayerViewController,
        coordinator: ()
    ) {
        // Release the player so the next AVPlayerViewController can cleanly take it.
        uiViewController.player = nil
    }
}
#endif
