#if os(iOS)
import SwiftUI
import UIKit
import VLCKit

/// The inline (in-detail) VLC player. A single, persistent VLC surface is
/// hosted here; fullscreen is a *separate* `UIViewController`
/// (`FullscreenPlayerViewController`) presented modally, so this view
/// never reshapes itself for fullscreen — it only ever renders inline.
public struct VLCPlayerView: View {
    public init() {}

    public var body: some View {
        ZStack {
            VLCVideoRenderView()
                .allowsHitTesting(false)

            PlayerControlsOverlay()
        }
        .clipped()
    }
}

// MARK: - VLC Video Render View

/// Hosts the persistent video output `UIView` owned by
/// `PlaybackServiceBackend` for a specific role. Only the host whose role
/// matches `PlayerManager.activePlayerSurfaceRole` adopts the player view
/// — and only while the fullscreen player VC is *not* presented, since
/// that VC owns the surface directly while it's up.
public struct VLCVideoRenderView: View {
    public var role: PlayerSurfaceRole

    public init(role: PlayerSurfaceRole = .fullDetail) {
        self.role = role
    }

    public var body: some View {
        let manager = PlayerManager.shared
        _ = manager.persistentVLCPlayerView
        // Passing `isVLCFullscreen` as a property forces SwiftUI to call
        // `updateUIView` when the fullscreen VC presents/dismisses — so
        // the inline host re-adopts the surface the moment fullscreen ends.
        return VLCPlayerHostRepresentable(
            shouldAdopt: manager.activePlayerSurfaceRole == role
                && !manager.isVLCFullscreen,
            fullscreenToken: manager.isVLCFullscreen
        )
    }
}

private struct VLCPlayerHostRepresentable: UIViewRepresentable {
    var shouldAdopt: Bool
    var fullscreenToken: Bool

    func makeUIView(context: Context) -> VLCPlayerHostView {
        let host = VLCPlayerHostView()
        host.backgroundColor = .black
        return host
    }

    func updateUIView(_ host: VLCPlayerHostView, context: Context) {
        // Only the adopting host actively grabs the player view. The
        // non-adopting host MUST NOT call `removeFromSuperview` here —
        // `addSubview` on the adopting host already reparents, and the
        // intermediate "orphaned, no window" state in between makes VLC
        // pause its video output. While the fullscreen VC is presented
        // `shouldAdopt` is false, so this host leaves the surface alone.
        if shouldAdopt {
            host.adoptPlayerView()
        }
    }

    static func dismantleUIView(_ host: VLCPlayerHostView, coordinator: ()) {
        host.detachPlayerView()
    }
}

/// Container UIView that adopts the persistent video output view vended by
/// `PlayerManager` as a pinned subview. Reparenting the
/// `PlaybackServiceBackend`-owned view between hosts is what makes the
/// inline ↔ fullscreen transition seamless: the underlying
/// `VLCMediaPlayer` is never recreated.
public final class VLCPlayerHostView: UIView {
    private var lastBoundsSize: CGSize = .zero
    private var pendingRefresh: DispatchWorkItem?

    func adoptPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView else { return }

        if playerView.superview === self { return }

        // `addSubview` already removes the player view from any previous
        // host. Avoid an explicit `removeFromSuperview` first — that
        // intermediate orphaned state used to make VLC pause its video
        // output, causing a black surface after reparenting.
        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func detachPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView,
              playerView.superview === self else { return }
        playerView.removeFromSuperview()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // The inline player lives in a portrait-locked screen, so this is
        // effectively dormant — but keep a single debounced drawable
        // rebind as a safety net for any unexpected inline bounds change
        // (split-view resize, etc.). Fullscreen rotation is handled by
        // `FullscreenPlayerViewController`, not here.
        let size = bounds.size
        guard size != .zero else { return }
        if lastBoundsSize == .zero {
            lastBoundsSize = size
            return
        }
        guard size != lastBoundsSize else { return }
        lastBoundsSize = size

        pendingRefresh?.cancel()
        let work = DispatchWorkItem {
            PlayerManager.shared.refreshVideoOutput()
        }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }
}
#endif
