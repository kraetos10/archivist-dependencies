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

            VStack(alignment: .leading, spacing: 12) {
                Spacer()

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
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 40)
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
        playerView.activatePlayback()
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
