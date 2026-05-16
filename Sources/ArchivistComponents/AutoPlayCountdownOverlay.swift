import SwiftUI

/// "Up next" auto-play countdown card shown over the player while the
/// auto-advance timer runs. Driven by `AutoPlayCountdownInfo` so it works
/// both inline (fed from the `VideoDetail` store) and in the fullscreen
/// player VC (fed from `PlayerManager.autoPlayCountdown`).
public struct AutoPlayCountdownOverlay: View {
    let info: AutoPlayCountdownInfo
    let onPlayNow: () -> Void
    let onCancel: () -> Void

    public init(
        info: AutoPlayCountdownInfo,
        onPlayNow: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.info = info
        self.onPlayNow = onPlayNow
        self.onCancel = onCancel
    }

    private var progress: CGFloat {
        guard info.totalSeconds > 0 else { return 0 }
        return CGFloat(info.remainingSeconds) / CGFloat(info.totalSeconds)
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            HStack(spacing: 14) {
                ZStack {
                    AsyncImage(url: info.thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.Brand.secondary.opacity(0.3))
                        }
                    }
                    .frame(width: 160, height: 90)
                    .clipped()

                    Rectangle().fill(.black.opacity(0.45))

                    countdownRing
                }
                .frame(width: 160, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text(String.localised("video.upNext", table: .videos))
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)

                    Text(info.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Button(action: onPlayNow) {
                            Label(
                                String.localised("video.autoPlayPlayNow", table: .videos),
                                systemImage: "play.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: onCancel) {
                            Text(String.localised("generic.cancel", table: .generic))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    .white,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: progress)

            Text("\(info.remainingSeconds)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.25), value: info.remainingSeconds)
        }
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.5), radius: 6)
    }
}
