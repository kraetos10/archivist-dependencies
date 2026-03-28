#if os(iOS)
import SwiftUI
import UIKit

public struct VLCPlayerView: View {
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?

    private let playerManager = PlayerManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            VLCVideoRenderView()
                .allowsHitTesting(false)

            if playerManager.isBuffering && !playerManager.isPlaying {
                Color.black.opacity(0.4)
                    .allowsHitTesting(false)
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .allowsHitTesting(false)
            }

            if controlsVisible {
                controlsOverlay
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible = true
                        }
                        scheduleHideControls()
                    }
            }
        }
        .clipped()
        .onAppear {
            scheduleHideControls()
        }
    }

    private var controlsOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible = false
                        }
                    }

                HStack(spacing: 40) {
                    Button {
                        playerManager.skipBackward(10)
                        scheduleHideControls()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title)
                            .foregroundStyle(.white)
                    }

                    Button {
                        playerManager.togglePlayPause()
                        scheduleHideControls()
                    } label: {
                        Image(
                            systemName: playerManager.isPlaying
                                ? "pause.circle.fill"
                                : "play.circle.fill"
                        )
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                    }

                    Button {
                        playerManager.skipForward(10)
                        scheduleHideControls()
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 24)

                VStack(spacing: 4) {
                    SeekBar(
                        progress: playerManager.duration > 0
                            ? playerManager.currentTime / playerManager.duration
                            : 0,
                        onDragStarted: {
                            hideControlsTask?.cancel()
                        },
                        onSeek: { value in
                            let target = value * playerManager.duration
                            playerManager.seekTo(target)
                            scheduleHideControls()
                        }
                    )

                    HStack {
                        Text(formatTime(playerManager.currentTime))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(formatTime(playerManager.duration))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
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

// MARK: - VLC Video Render View

private struct VLCVideoRenderView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let vlcBackend = PlayerManager.shared.backend as? VLCPlayerBackend {
            if vlcBackend.mediaPlayer.drawable as? UIView !== uiView {
                vlcBackend.attachDrawable(uiView)
            }
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Release the drawable so VLC doesn't hold a reference to a dead view.
        // The backend keeps playing; a new VLCVideoRenderView will re-attach
        // its own UIView via attachDrawable() on the next presentation.
        if let vlcBackend = PlayerManager.shared.backend as? VLCPlayerBackend,
           vlcBackend.mediaPlayer.drawable as? UIView === uiView {
            vlcBackend.mediaPlayer.drawable = nil
        }
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
                    .frame(height: 4)

                Capsule()
                    .fill(.white)
                    .frame(
                        width: max(0, geometry.size.width * displayProgress),
                        height: 4
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .offset(
                        x: max(0, min(
                            geometry.size.width * displayProgress - 7,
                            geometry.size.width - 14
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
        .frame(height: 30)
    }
}
#endif
