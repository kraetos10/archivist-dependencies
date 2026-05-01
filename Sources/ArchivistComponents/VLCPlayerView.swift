#if os(iOS)
import SwiftUI
import UIKit
import VLCKit

public struct VLCPlayerView: View {
    @Bindable private var playerManager = PlayerManager.shared

    public init() {}

    public var body: some View {
        // Single-instance, no fullScreenCover. Fullscreen is driven by the
        // host (`VideoDetailScreen`) reshaping its layout — keeps the same
        // SwiftUI identity across the toggle so the persistent VLC UIView
        // doesn't get reparented (which is what was producing the black
        // frame on every fullscreen flip).
        ZStack {
            playerContent
        }
        .clipped()
        .onAppear {
            playerManager.scheduleHideVLCControls()
        }
    }

    private var playerContent: some View {
        // True only on the first load, before VLC has produced a single
        // tick. We treat this as "stream is being resolved" — full dim
        // and no controls. After we've seen any time, we're in
        // mid-playback territory: any subsequent buffering is a rebuffer,
        // so we keep the controls live and just overlay a spinner.
        let isInitialLoad = playerManager.isBuffering && playerManager.currentTime == 0

        return ZStack {
            VLCVideoRenderView()
                .allowsHitTesting(false)

            if !isInitialLoad {
                if playerManager.vlcControlsVisible {
                    controlsOverlay
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playerManager.showVLCControls()
                        }
                }
            }

            if playerManager.isBuffering {
                if isInitialLoad {
                    Color.black.opacity(0.4)
                        .allowsHitTesting(false)
                }
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .allowsHitTesting(false)
            }
        }
    }

    private var controlsOverlay: some View {
        // Pad the controls outside the device's safe area only when we're
        // in fullscreen — that's the only mode where the host
        // (`VideoDetailScreen`) ignores safe-area, so the player extends
        // under the dynamic island / home indicator. In inline mode the
        // parent already places us below the chrome, so any extra offset
        // would push the controls into the middle of the player.
        let fs = playerManager.isVLCFullscreen
        let safeArea = fs ? Self.windowSafeAreaInsets : .zero
        return Color.black.opacity(0.35)
            .contentShape(Rectangle())
            .onTapGesture {
                playerManager.hideVLCControls()
            }
            .overlay(alignment: .topLeading) {
                titleRow
                    .padding(.leading, 16 + safeArea.left)
                    .padding(.top, 16 + safeArea.top)
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    roundedControlButton(
                        systemImage: "pip.enter",
                        iconSize: 16,
                        padding: 12
                    ) {
                        playerManager.startPiPIfAvailable()
                        playerManager.scheduleHideVLCControls()
                    }

                    roundedControlButton(
                        systemImage: playerManager.isVLCFullscreen
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right",
                        iconSize: 18,
                        padding: 12
                    ) {
                        playerManager.toggleVLCFullscreen()
                    }
                }
                .padding(.trailing, 16 + safeArea.right)
                .padding(.top, 16 + safeArea.top)
            }
            .overlay { centerTransportControls }
            .overlay(alignment: .bottom) {
                bottomInfoAndSeek
                    .padding(.bottom, safeArea.bottom)
            }
    }

    /// Snapshot of the foreground window's safe area insets. Used when
    /// the host applies `.ignoresSafeArea` so the controls overlay can
    /// still keep clear of the dynamic island / home indicator.
    private static var windowSafeAreaInsets: UIEdgeInsets {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return .zero }
        return window.safeAreaInsets
    }

    // MARK: - Center transport

    private var centerTransportControls: some View {
        HStack(spacing: 36) {
            roundedControlButton(
                systemImage: "backward.end.fill",
                iconSize: 24,
                padding: 18,
                isEnabled: playerManager.canGoPrevious
            ) {
                playerManager.onPreviousRequested?()
                playerManager.scheduleHideVLCControls()
            }

            roundedControlButton(
                systemImage: playerManager.isPlaying ? "pause.fill" : "play.fill",
                iconSize: 34,
                padding: 22
            ) {
                playerManager.togglePlayPause()
                playerManager.scheduleHideVLCControls()
            }

            roundedControlButton(
                systemImage: "forward.end.fill",
                iconSize: 24,
                padding: 18
            ) {
                playerManager.onNextRequested?()
                playerManager.scheduleHideVLCControls()
            }
        }
    }

    private func roundedControlButton(
        systemImage: String,
        iconSize: CGFloat,
        padding: CGFloat,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize + padding * 2, height: iconSize + padding * 2)
                .background(.black.opacity(0.45))
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }

    // MARK: - Bottom info + seek bar

    private var bottomInfoAndSeek: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(playerManager.currentTimeDisplay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(playerManager.durationDisplay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            SeekBar(
                progress: playerManager.duration > 0
                    ? playerManager.currentTime / playerManager.duration
                    : 0,
                onDragStarted: {
                    playerManager.cancelVLCHideControls()
                },
                onSeek: { value in
                    let target = value * playerManager.duration
                    playerManager.seekTo(target)
                    playerManager.scheduleHideVLCControls()
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private var titleRow: some View {
        if let metadata = playerManager.currentMetadata {
            HStack(spacing: 10) {
                if let thumbURL = metadata.channelThumbURL {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Circle().fill(.white.opacity(0.2))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }
                Text(metadata.artist)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("·")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Text(metadata.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - VLC Video Render View

/// Hosts the persistent `UIVLCVideoPlayerView` owned by `VLCPlayerBackend`
/// for a specific role. Only the host whose role matches
/// `PlayerManager.activePlayerSurfaceRole` adopts the player view; the
/// other shows nothing. Same anti-race pattern as
/// `AVPlayerViewControllerWrapper`.
public struct VLCVideoRenderView: View {
    public var role: PlayerSurfaceRole

    public init(role: PlayerSurfaceRole = .fullDetail) {
        self.role = role
    }

    public var body: some View {
        let manager = PlayerManager.shared
        _ = manager.persistentVLCPlayerView
        // Passing `isVLCFullscreen` as a property forces SwiftUI to call
        // `updateUIView` on both hosts when the fullscreen cover toggles —
        // otherwise the underlying host keeps its stale "I don't own the
        // player view" state after the cover dismisses and renders black.
        return VLCPlayerHostRepresentable(
            shouldAdopt: manager.activePlayerSurfaceRole == role,
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
        // Only the adopting host actively grabs the player view.
        // The non-adopting host MUST NOT call `removeFromSuperview` here
        // — `addSubview` on the adopting host already reparents, and the
        // intermediate "orphaned, no window" state in between makes VLC
        // pause its video output. Detach is reserved for `dismantleUIView`
        // (host going away) so SwiftUI doesn't leave the view dangling
        // inside a destroyed host.
        if shouldAdopt {
            host.adoptPlayerView()
        }
    }

    static func dismantleUIView(_ host: VLCPlayerHostView, coordinator: ()) {
        host.detachPlayerView()
    }
}

/// Container UIView that adopts the persistent `UIVLCVideoPlayerView`
/// vended by `PlayerManager` as a pinned subview. Reparenting the
/// VLCUI-owned view between hosts is what makes the mini player ↔ full
/// transition seamless: the underlying `VLCMediaPlayer` is never recreated.
public final class VLCPlayerHostView: UIView {
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

        // Explicit kick so we don't depend solely on `didMoveToWindow`
        // timing — `fullScreenCover`'s window setup is async and the
        // notification can land after we expect playback to have begun.
        // `activatePlayback` is idempotent.
        playerView.activatePlayback()
    }

    func detachPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView,
              playerView.superview === self else { return }
        playerView.removeFromSuperview()
    }
}

// MARK: - Seek Bar

private struct SeekBar: View {
    let progress: Double
    var onDragStarted: (() -> Void)?
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var displayProgress: Double {
        isDragging ? dragProgress : progress
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: 6)

                Capsule()
                    .fill(.white)
                    .frame(
                        width: max(0, geometry.size.width * displayProgress),
                        height: 6
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(
                        x: max(0, min(
                            geometry.size.width * displayProgress - 9,
                            geometry.size.width - 18
                        ))
                    )
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStarted?()
                        }
                        let ratio = value.location.x / geometry.size.width
                        dragProgress = min(max(ratio, 0), 1)
                    }
                    .onEnded { value in
                        let ratio = value.location.x / geometry.size.width
                        let clamped = min(max(ratio, 0), 1)
                        onSeek(clamped)
                        isDragging = false
                    }
            )
        }
        .frame(height: 36)
    }
}
#endif
