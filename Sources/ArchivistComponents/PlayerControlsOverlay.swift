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
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled

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
                        onPlayNow: { playerManager.emit(.autoPlayPlayNowTapped) },
                        onCancel: { playerManager.emit(.autoPlayCancelTapped) }
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
        // `PlayerManager` stops auto-hiding while VoiceOver runs; bring the
        // chrome back if it was already hidden when VoiceOver came on.
        .onChange(of: isVoiceOverEnabled) { _, isEnabled in
            if isEnabled, !childModeEnabled {
                playerManager.showVLCControls()
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
                tapAreas
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    speedButton

                    roundedControlButton(
                        systemImage: "pip.enter",
                        label: String.localised("video.pictureInPicture", table: .videos),
                        iconSize: 16,
                        padding: 12
                    ) {
                        pictureInPictureTapped()
                    }

                    if playerManager.isVLCFullscreen {
                        roundedControlButton(
                            systemImage: "rotate.right",
                            label: String.localised("video.rotate", table: .videos),
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
                            label: playerManager.isVLCFullscreen
                                ? String.localised("video.exitFullscreen", table: .videos)
                                : String.localised("video.enterFullscreen", table: .videos),
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

    private func pictureInPictureTapped() {
        playerManager.startPiPIfAvailable()
        playerManager.scheduleHideVLCControls()
        // PiP renders through its own window — leaving the fullscreen VC up
        // would just show a black surface behind the PiP tile. Drop back to
        // the inline detail screen.
        if playerManager.isVLCFullscreen {
            playerManager.exitFullscreen()
        }
    }

    // MARK: - Speed

    /// Shows the current speed and opens the picker. The picker is a
    /// confirmation dialog rather than a `Menu` because the controls
    /// auto-hide: a `Menu` gives no signal that it's open, so the hide timer
    /// would pull the button out from under it. The dialog's presentation is
    /// state `PlayerManager` can see, and it holds the controls up meanwhile.
    private var speedButton: some View {
        Button {
            playerManager.showSpeedPicker()
        } label: {
            Text(playerManager.playbackSpeedLabel)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minWidth: 42, minHeight: 42)
                .background(.black.opacity(0.45))
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String.localised("video.playbackSpeed", table: .videos))
        .accessibilityValue(playerManager.playbackSpeedLabel)
        .confirmationDialog(
            String.localised("video.playbackSpeed", table: .videos),
            isPresented: $playerManager.isSpeedPickerPresented,
            titleVisibility: .visible
        ) {
            ForEach(PlaybackSpeed.options, id: \.self) { speed in
                Button(PlaybackSpeed.label(for: speed)) {
                    playerManager.setPlaybackSpeed(speed)
                }
            }
        }
    }

    // MARK: - Tap areas

    /// Two equal-width halves overlaying the player. Each half handles
    /// both gestures: double-tap skips ±15s; single tap toggles control
    /// visibility. Both modifiers attached to the same view so SwiftUI's
    /// gesture disambiguation routes a double-tap to the count:2 handler
    /// without firing the single-tap first.
    ///
    /// For VoiceOver the pair is one button that shows or hides the
    /// controls, with the skips as named actions — bare `onTapGesture`
    /// zones carry no traits and would otherwise be unreachable.
    private var tapAreas: some View {
        HStack(spacing: 0) {
            tapHalf(skip: { playerManager.skipBackward(15) })
            tapHalf(skip: { playerManager.skipForward(15) })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            playerManager.vlcControlsVisible
                ? String.localised("video.controls.hide", table: .videos)
                : String.localised("video.controls.show", table: .videos)
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { controlsTapped() }
        .accessibilityAction(named: String.localised("video.skipBackward", table: .videos)) {
            playerManager.skipBackward(15)
        }
        .accessibilityAction(named: String.localised("video.skipForward", table: .videos)) {
            playerManager.skipForward(15)
        }
    }

    private func tapHalf(skip: @escaping () -> Void) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                skip()
                HapticFeedback.light.play()
            }
            .onTapGesture { controlsTapped() }
    }

    private func controlsTapped() {
        if playerManager.vlcControlsVisible {
            playerManager.hideVLCControls()
        } else {
            playerManager.showVLCControls()
        }
    }

    /// - Parameter label: Spoken name for the control. Required rather than
    ///   optional — these buttons are icon-only, so without it VoiceOver
    ///   falls back to reading the SF Symbol name ("pip dot enter").
    ///
    /// The icon size stays fixed under Dynamic Type on purpose: this is
    /// player chrome laid out over video at a size the surrounding
    /// transport row depends on, and it matches how the system player
    /// behaves.
    private func roundedControlButton(
        systemImage: String,
        label: String,
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
        .accessibilityLabel(label)
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
                playPauseTapped()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                playerManager.isPlaying
                    ? String.localised("video.pause", table: .videos)
                    : String.localised("video.play", table: .videos)
            )
            // The ±15s skips are double-tap zones over the video, which
            // VoiceOver can't surface. Hang them off the transport button
            // as rotor actions so they're still reachable.
            .accessibilityAction(named: String.localised("video.skipBackward", table: .videos)) {
                playerManager.skipBackward(15)
            }
            .accessibilityAction(named: String.localised("video.skipForward", table: .videos)) {
                playerManager.skipForward(15)
            }

            SeekBar(
                progress: playerManager.playbackFraction,
                accessibilityValue: String.localised(
                    "video.progressValue \(playerManager.currentTimeDisplay) \(playerManager.durationDisplay)",
                    table: .videos
                ),
                onDragStarted: { playerManager.cancelVLCHideControls() },
                onSeek: { seekEnded(atFraction: $0) },
                onIncrement: { playerManager.skipForward(15) },
                onDecrement: { playerManager.skipBackward(15) }
            )

            Text("\(playerManager.currentTimeDisplay) / \(playerManager.durationDisplay)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private func playPauseTapped() {
        playerManager.togglePlayPause()
        playerManager.scheduleHideVLCControls()
    }

    private func seekEnded(atFraction fraction: Double) {
        playerManager.seek(toFraction: fraction)
        playerManager.scheduleHideVLCControls()
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
                    // Decorative: the channel name beside it says who it is.
                    .accessibilityHidden(true)
                }
                Text(metadata.artist)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("·")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
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
    /// Spoken position, e.g. "1:02 of 10:30".
    let accessibilityValue: String
    var onDragStarted: (() -> Void)?
    let onSeek: (Double) -> Void
    /// VoiceOver swipe up / down on the adjustable element.
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var displayProgress: Double {
        // Clamp to [0, 1] — `progress` is `currentTime / duration`, which
        // can momentarily exceed 1 (currentTime overshooting a stale/short
        // duration at end-of-video or just after a resume). Without this
        // the fill capsule's width runs past the track's max bound.
        min(max(isDragging ? dragProgress : progress, 0), 1)
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
        .accessibilityElement()
        .accessibilityLabel(String.localised("video.watchProgress", table: .videos))
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onIncrement()
            case .decrement: onDecrement()
            @unknown default: break
            }
        }
    }
}
#endif
