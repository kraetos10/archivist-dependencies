#if os(tvOS)
import SwiftUI
import UIKit

public struct TVVLCPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let playerManager = PlayerManager.shared

    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        ZStack {
            TVVLCVideoRenderView()
                .ignoresSafeArea()
                // Stop the embedded VLC host UIView from intercepting
                // tvOS focus / remote events — without this the press
                // events captured below never reach our handler.
                .allowsHitTesting(false)

            if playerManager.isBuffering {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if controlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }

            // Press-event capture: `.onMoveCommand` only fires once per
            // press cycle so it can't distinguish a quick tap from a
            // hold. Routing the right/left arrow through UIPress lets
            // us treat a sub-300ms press as a discrete skip and a
            // longer hold as a 4× fast-forward via `setPlaybackRate`.
            TVPlayerPressView(
                onTap: { type in handleTap(type) },
                onHoldBegan: { type in handleHoldBegan(type) },
                onHoldEnded: { type in handleHoldEnded(type) }
            )
        }
        .onAppear { poke() }
        .onDisappear {
            hideTask?.cancel()
            // Restore the rate in case the view is dismissed mid-hold,
            // otherwise the next playback session inherits 4× speed.
            playerManager.setPlaybackRate(1.0)
        }
    }

    private func handleTap(_ type: UIPress.PressType) {
        switch type {
        case .leftArrow:
            playerManager.skipBackward(10)
            poke()
        case .rightArrow:
            playerManager.skipForward(10)
            poke()
        case .playPause, .select:
            playerManager.togglePlayPause()
            poke()
        case .menu:
            dismiss()
        default:
            poke()
        }
    }

    private func handleHoldBegan(_ type: UIPress.PressType) {
        switch type {
        case .rightArrow:
            playerManager.setPlaybackRate(4.0)
            poke()
        default:
            break
        }
    }

    private func handleHoldEnded(_ type: UIPress.PressType) {
        switch type {
        case .rightArrow:
            playerManager.setPlaybackRate(1.0)
            poke()
        default:
            break
        }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let metadata = playerManager.currentMetadata {
                HStack(spacing: 12) {
                    if let thumb = metadata.channelThumbURL {
                        AsyncImage(url: thumb) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Circle().fill(.white.opacity(0.2))
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    }
                    Text(metadata.artist)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("·")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(metadata.title)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                progressBar(
                    progress: playerManager.duration > 0
                        ? playerManager.currentTime / playerManager.duration
                        : 0
                )

                HStack {
                    Text(formatTime(playerManager.currentTime))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(formatTime(playerManager.duration))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
    }

    /// Custom progress bar — the SwiftUI default `ProgressView` has a
    /// barely-visible track on a dark background. This always renders both
    /// the unfilled and filled portions clearly.
    private func progressBar(progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 6)
                Capsule()
                    .fill(Color.white)
                    .frame(
                        width: max(0, geometry.size.width * progress),
                        height: 6
                    )
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 6)
    }

    /// Show controls and reset the auto-hide timer. Called on appear and
    /// any user input (play/pause, skip).
    private func poke() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
        }
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible = false
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Captures raw UIPress events from the Siri Remote so the player can
/// distinguish a quick tap from a press-and-hold. Discrete arrow taps
/// dispatch as `onTap`; presses still active after `holdThreshold`
/// dispatch `onHoldBegan` and matching `onHoldEnded` on release.
private struct TVPlayerPressView: UIViewRepresentable {
    let onTap: (UIPress.PressType) -> Void
    let onHoldBegan: (UIPress.PressType) -> Void
    let onHoldEnded: (UIPress.PressType) -> Void

    func makeUIView(context: Context) -> TVPressTrackingView {
        let view = TVPressTrackingView()
        view.onTap = onTap
        view.onHoldBegan = onHoldBegan
        view.onHoldEnded = onHoldEnded
        return view
    }

    func updateUIView(_ uiView: TVPressTrackingView, context: Context) {
        uiView.onTap = onTap
        uiView.onHoldBegan = onHoldBegan
        uiView.onHoldEnded = onHoldEnded
    }
}

private final class TVPressTrackingView: UIView {
    var onTap: ((UIPress.PressType) -> Void)?
    var onHoldBegan: ((UIPress.PressType) -> Void)?
    var onHoldEnded: ((UIPress.PressType) -> Void)?

    /// Threshold above which a press is treated as a hold rather than
    /// a discrete tap.
    private let holdThreshold: Duration = .milliseconds(300)

    private var holdTimers: [UIPress.PressType: Task<Void, Never>] = [:]
    private var heldPresses: Set<UIPress.PressType> = []

    override var canBecomeFocused: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            switch press.type {
            case .leftArrow, .rightArrow, .playPause, .select, .menu:
                schedule(press.type)
            default:
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            switch press.type {
            case .leftArrow, .rightArrow, .playPause, .select, .menu:
                resolve(press.type)
            default:
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesEnded(unhandled, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            cancel(press.type)
        }
        super.pressesCancelled(presses, with: event)
    }

    private func schedule(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = Task { @MainActor [weak self, holdThreshold] in
            try? await Task.sleep(for: holdThreshold)
            guard let self, !Task.isCancelled else { return }
            self.heldPresses.insert(type)
            self.onHoldBegan?(type)
        }
    }

    private func resolve(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = nil
        if heldPresses.remove(type) != nil {
            onHoldEnded?(type)
        } else {
            onTap?(type)
        }
    }

    private func cancel(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = nil
        if heldPresses.remove(type) != nil {
            onHoldEnded?(type)
        }
    }
}

private final class TVVLCPlayerHostView: UIView {
    func adoptPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView else { return }
        if playerView.superview === self { return }

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
}

private struct TVVLCVideoRenderView: UIViewRepresentable {
    func makeUIView(context: Context) -> TVVLCPlayerHostView {
        let view = TVVLCPlayerHostView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: TVVLCPlayerHostView, context: Context) {
        uiView.adoptPlayerView()
    }

    static func dismantleUIView(_ uiView: TVVLCPlayerHostView, coordinator: ()) {
        uiView.detachPlayerView()
    }
}
#endif
