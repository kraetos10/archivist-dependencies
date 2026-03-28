#if os(tvOS)
import SwiftUI
import UIKit

public struct TVVLCPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let playerManager = PlayerManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            TVVLCVideoRenderView()
                .ignoresSafeArea()

            if playerManager.isBuffering {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            VStack {
                Spacer()

                VStack(spacing: 8) {
                    ProgressView(
                        value: playerManager.duration > 0
                            ? playerManager.currentTime / playerManager.duration
                            : 0
                    )
                    .tint(.white)

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
                .padding(.horizontal, 80)
                .padding(.bottom, 40)
            }
        }
        .onPlayPauseCommand {
            playerManager.togglePlayPause()
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                playerManager.skipBackward(10)
            case .right:
                playerManager.skipForward(10)
            default:
                break
            }
        }
        .onExitCommand {
            dismiss()
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

private class TVVLCDrawableView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        Task { @MainActor in
            if let vlcBackend = PlayerManager.shared.backend as? VLCPlayerBackend {
                vlcBackend.attachDrawable(self)
            }
        }
    }
}

private struct TVVLCVideoRenderView: UIViewRepresentable {
    func makeUIView(context: Context) -> TVVLCDrawableView {
        let view = TVVLCDrawableView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: TVVLCDrawableView, context: Context) {}
}
#endif
