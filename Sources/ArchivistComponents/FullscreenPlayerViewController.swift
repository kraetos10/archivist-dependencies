#if os(iOS)
import SwiftUI
import UIKit

/// Dedicated fullscreen player container, modelled on videolan/vlc-ios'
/// `VideoPlayerViewController`.
///
/// The previous implementation faked fullscreen by reshaping a SwiftUI
/// layout in `VideoDetailScreen`. That meant rotation was driven by
/// SwiftUI re-layout + surface reparenting, and the VLC drawable's Metal
/// layer would keep a stale `drawableSize` — audio kept playing while the
/// picture went black. Multiple timer-based recovery paths then raced
/// each other and made it worse.
///
/// Here the player surface is owned by a real `UIViewController`. UIKit
/// drives the rotation transition natively (`viewWillTransition`), the
/// persistent VLC view resizes via autoresizing exactly like vlc-ios, and
/// a single drawable nudge fires *once* when the transition commits — no
/// timers, no race.
@MainActor
public final class FullscreenPlayerViewController: UIViewController {

    /// Plain container the persistent VLC surface is pinned inside.
    private let videoHost: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// SwiftUI chrome (transport, seek, buttons) layered above the video.
    private lazy var controlsHost: UIHostingController<PlayerControlsOverlay> = {
        let host = UIHostingController(rootView: PlayerControlsOverlay())
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        return host
    }()

    public override var prefersStatusBarHidden: Bool { true }
    public override var prefersHomeIndicatorAutoHidden: Bool { true }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(videoHost)

        addChild(controlsHost)
        view.addSubview(controlsHost.view)
        controlsHost.didMove(toParent: self)

        NSLayoutConstraint.activate([
            videoHost.topAnchor.constraint(equalTo: view.topAnchor),
            videoHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            videoHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            controlsHost.view.topAnchor.constraint(equalTo: view.topAnchor),
            controlsHost.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlsHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        adoptPlayerView()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Cheap idempotent guard — re-grab the surface if anything else
        // reparented it. `adoptPlayerView` no-ops when we already own it.
        adoptPlayerView()
    }

    public override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        // The persistent VLC view and its `_actualVideoOutputView` resize
        // via autoresizing during the transition. The only thing that
        // doesn't follow a plain bounds change is the render layer's
        // Metal `drawableSize` — nudge the drawable exactly once, after
        // UIKit has committed the final post-rotation bounds.
        coordinator.animate(alongsideTransition: nil) { _ in
            PlayerManager.shared.refreshVideoOutput()
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Restore portrait lock and clear the fullscreen flag. Flipping
        // `isVLCFullscreen` triggers the inline `VLCVideoRenderView` to
        // re-adopt the persistent surface (see its `fullscreenToken`).
        PlayerManager.shared.isVLCFullscreen = false
        PlayerManager.shared.clearActiveFullscreenViewController(self)
        OrientationLock.shared.lockPortrait()
    }

    /// Re-grab the current persistent surface. Called by `PlayerManager`
    /// on auto-advance, where the next video's backend vends a brand-new
    /// `playerView` that must be pulled into the fullscreen container.
    public func adoptCurrentPlayerView() {
        adoptPlayerView()
    }

    /// Reparent the persistent VLC surface into `videoHost`. Uses
    /// autoresizing (not Auto Layout) so reparenting across hosts never
    /// leaves stale cross-hierarchy constraints — and so it matches how
    /// vlc-ios pins its video output view.
    private func adoptPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView else { return }
        if playerView.superview === videoHost { return }

        playerView.translatesAutoresizingMaskIntoConstraints = true
        playerView.frame = videoHost.bounds
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // `addSubview` already removes it from any previous host.
        videoHost.addSubview(playerView)
    }
}

// MARK: - Presentation

/// Presents / dismisses `FullscreenPlayerViewController`. Kept separate
/// from `PlayerManager` so the manager stays free of UIKit-traversal
/// concerns.
@MainActor
enum FullscreenPlayerPresenter {
    static func present() {
        guard PlayerManager.shared.activeFullscreenViewController == nil,
              let top = topViewController() else { return }

        let controller = FullscreenPlayerViewController()
        // `.overFullScreen` (not `.fullScreen`): the presenter's view stays
        // in the hierarchy, so the underlying `VideoDetailScreen` does NOT
        // receive `onDisappear`/`onAppear` — no spurious `viewDidAppear`
        // re-fire and data reload when fullscreen ends. The VC's black
        // background still fully covers the screen.
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.modalPresentationCapturesStatusBarAppearance = true
        PlayerManager.shared.setActiveFullscreenViewController(controller)
        top.present(controller, animated: true)
    }

    static func dismiss() {
        guard let controller = PlayerManager.shared.activeFullscreenViewController else { return }
        controller.dismiss(animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
