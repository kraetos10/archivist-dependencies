#if os(iOS)
import SwiftUI
import UIKit

/// The SwiftUI player chrome — tap areas, transport, seek bar, buffering
/// spinner. Rendered as a transparent layer *on top of* the VLC video
/// surface. Used in two places:
///
/// * Inline, inside `VLCPlayerView` (the small in-detail player).
/// * Fullscreen, hosted by `FullscreenPlayerViewController` via a
///   `UIHostingController` layered over the VC's video host.
///
/// It owns no video surface of its own — `PlayerManager.shared` is the
/// single source of truth, so the same overlay works regardless of which
/// container is currently hosting the persistent VLC view.
public struct PlayerControlsOverlay: View {
    @Bindable private var playerManager = PlayerManager.shared
    @AppStorage(ChildMode.enabledKey) private var childModeEnabled = false

    public init() {}

    public var body: some View {
        // True only on the first load, before VLC has produced a single
        // tick. We treat this as "stream is being resolved" — full dim
        // and no controls. After we've seen any time, we're in
        // mid-playback territory: any subsequent buffering is a rebuffer,
        // so we keep the controls live and just overlay a spinner.
        let isInitialLoad = playerManager.isBuffering && playerManager.currentTime == 0

        return GeometryReader { geo in
            ZStack {
                // Child mode wraps the player in `ChildVideoPlayerScreen`
                // which renders its own close button, transport, and similar
                // videos rail — suppress VLC's built-in controls here so the
                // two layers don't fight over taps and z-order.
                if !childModeEnabled, !isInitialLoad {
                    tapAreas

                    if playerManager.vlcControlsVisible {
                        // Only the fullscreen player extends under the
                        // device safe area — inline, the parent already
                        // places us below the chrome, so applying insets
                        // would shove the controls inward off the edge.
                        controlsOverlay(
                            safeArea: playerManager.isVLCFullscreen
                                ? geo.safeAreaInsets
                                : EdgeInsets()
                        )
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

                // Auto-play "up next" card. Surfaced here only for the
                // fullscreen player VC — the inline detail screen renders
                // its own copy over the thumbnail (the inline `VLCPlayerView`
                // is unmounted while the countdown runs, since playback has
                // stopped). Mirrored from the reducer via `PlayerManager`.
                if !childModeEnabled,
                   playerManager.isVLCFullscreen,
                   let countdown = playerManager.autoPlayCountdown {
                    AutoPlayCountdownOverlay(
                        info: countdown,
                        onPlayNow: { playerManager.onAutoPlayPlayNow?() },
                        onCancel: { playerManager.onAutoPlayCancel?() }
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            // Child mode runs its own always-visible chrome from
            // `ChildVideoPlayerScreen`; don't kick off the VLC auto-hide
            // timer in that case — it'd just race our overlay state.
            if !childModeEnabled {
                playerManager.scheduleHideVLCControls()
            }
        }
    }

    private func controlsOverlay(safeArea: EdgeInsets) -> some View {
        // Dim layer behind the buttons. Single-tap hides the controls;
        // double-tap on either half still triggers a ±15s skip so the
        // gesture works regardless of whether controls are visible.
        //
        // `safeArea` comes straight from the hosting `GeometryReader`:
        // device insets when fullscreen (the hosting controller fills the
        // screen), `.zero` inline (the inline frame never touches a
        // screen edge). No window-insets snapshot needed.
        Color.black.opacity(0.35)
            .overlay {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        tapHalf(skip: { playerManager.skipBackward(15) })
                        tapHalf(skip: { playerManager.skipForward(15) })
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
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
                        // PiP renders through its own window — leaving the
                        // fullscreen VC up would just show a black surface
                        // behind the PiP tile. Drop back to the inline
                        // detail screen.
                        if playerManager.isVLCFullscreen {
                            playerManager.exitFullscreen()
                        }
                    }

                    if playerManager.isVLCFullscreen {
                        roundedControlButton(
                            systemImage: "rotate.right",
                            iconSize: 18,
                            padding: 12
                        ) {
                            // The fullscreen player is a real
                            // `UIViewController`, so the geometry request
                            // drives a native rotation transition and the
                            // VC's `viewWillTransition` handles the VLC
                            // drawable rebind. No manual reload needed.
                            OrientationLock.shared.rotateFullscreen()
                            playerManager.scheduleHideVLCControls()
                        }
                    }

                    // Child mode runs the player permanently fullscreen,
                    // so the toggle would be a no-op visual control —
                    // hide it.
                    if !childModeEnabled {
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
                }
                .padding(.trailing, 16 + safeArea.trailing)
                .padding(.top, 16 + safeArea.top)
            }
            .overlay(alignment: .bottom) {
                bottomInfoAndSeek
                    .padding(.bottom, safeArea.bottom)
            }
    }

    // MARK: - Tap areas

    /// Two equal-width halves overlaying the player. Each half handles
    /// both gestures: double-tap skips ±15s; single tap toggles control
    /// visibility. Both modifiers attached to the same view so SwiftUI's
    /// gesture disambiguation routes a double-tap to the count:2 handler
    /// without firing the single-tap first.
    private var tapAreas: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                tapHalf(skip: { playerManager.skipBackward(15) })
                tapHalf(skip: { playerManager.skipForward(15) })
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func tapHalf(skip: @escaping () -> Void) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                skip()
                HapticFeedback.light.play()
            }
            .onTapGesture {
                if playerManager.vlcControlsVisible {
                    playerManager.hideVLCControls()
                } else {
                    playerManager.showVLCControls()
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
        // Title above, transport+seek+time below.
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            transportRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    private var transportRow: some View {
        HStack(spacing: 12) {
            Button {
                playerManager.togglePlayPause()
                playerManager.scheduleHideVLCControls()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

            Text("\(playerManager.currentTimeDisplay) / \(playerManager.durationDisplay)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
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
            }
        }
    }
}

// MARK: - Seek Bar

struct SeekBar: View {
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
