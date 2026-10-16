#if os(tvOS)
import SwiftUI

/// The "up next" card on Apple TV, filling the player once a video ends.
/// Play Now starts focused, so Select skips the wait; Menu closes the
/// player, which cancels the countdown.
public struct TVAutoPlayCountdownOverlay: View {
    let info: AutoPlayCountdownInfo
    let onPlayNow: () -> Void
    let onCancel: () -> Void

    private enum Control { case playNow, cancel }
    @FocusState private var focused: Control?

    private static let artworkWidth: CGFloat = 640
    private static var artworkHeight: CGFloat { artworkWidth * 9 / 16 }

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
            backdrop

            HStack(spacing: 64) {
                artwork

                VStack(alignment: .leading, spacing: 20) {
                    Text(String.localised("video.upNext", table: .videos))
                        .font(.headline)
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(info.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    HStack(spacing: 24) {
                        Button(action: onPlayNow) {
                            Label(
                                String.localised("video.autoPlayPlayNow", table: .videos),
                                systemImage: "play.fill"
                            )
                        }
                        .focused($focused, equals: .playNow)

                        Button(String.localised("generic.cancel", table: .generic), action: onCancel)
                            .focused($focused, equals: .cancel)
                    }
                    .padding(.top, 12)
                }
                .frame(maxWidth: 800, alignment: .leading)
            }
        }
        .onAppear { focused = .playNow }
    }

    /// The next video's art, blurred and darkened, over the finished one.
    private var backdrop: some View {
        ZStack {
            Color.black
            AsyncImage(url: info.thumbnailURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                }
            }
            .blur(radius: 60)
            .opacity(0.5)
            Color.black.opacity(0.4)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var artwork: some View {
        ZStack {
            AsyncImage(url: info.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(Color.Brand.secondary.opacity(0.3))
                }
            }
            .frame(width: Self.artworkWidth, height: Self.artworkHeight)
            .clipped()

            Rectangle().fill(.black.opacity(0.35))

            countdownRing
        }
        .frame(width: Self.artworkWidth, height: Self.artworkHeight)
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        .accessibilityHidden(true)
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: progress)

            Text("\(info.remainingSeconds)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.25), value: info.remainingSeconds)
        }
        .frame(width: 128, height: 128)
        .shadow(color: .black.opacity(0.5), radius: 8)
    }
}
#endif
