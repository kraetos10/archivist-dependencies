#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

extension VideoDetailScreen {

    // MARK: - Player / Thumbnail

    @ViewBuilder
    func playerOrThumbnail(height: CGFloat) -> some View {
        ZStack {
            if store.isPlaying {
                VLCPlayerView()
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            } else {
                thumbnailView(height: height)
            }

            if let countdown = store.autoPlayCountdown {
                AutoPlayCountdownOverlay(
                    countdown: countdown,
                    serverConfig: store.serverConfig,
                    onPlayNow: { send(.autoPlayCountdownPlayNowTapped) },
                    onCancel: { send(.autoPlayCountdownCancelTapped) }
                )
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.autoPlayCountdown != nil)
    }

    func thumbnailView(height: CGFloat) -> some View {
        ZStack {
            if let thumbURL = thumbnailURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: height)
                            .clipped()
                    default:
                        thumbnailPlaceholder(height: height)
                    }
                }
            } else {
                thumbnailPlaceholder(height: height)
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 8)
        }
        .frame(height: height)
        .overlay(alignment: .bottom) {
            if store.effectiveWatchProgress > 0 {
                WatchProgressBar(
                    progress: store.effectiveWatchProgress,
                    height: 5
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.light.play()
            send(.playTapped)
        }
    }

    func thumbnailPlaceholder(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.Brand.secondary.opacity(0.3))
            .frame(height: height)
    }

    var thumbnailURL: URL? {
        guard let thumbPath = store.video.vidThumbUrl else { return nil }
        return store.serverConfig.fullURL(for: thumbPath)
    }
}

struct AutoPlayCountdownOverlay: View {
    let countdown: AutoPlayCountdown
    let serverConfig: ServerConfig
    let onPlayNow: () -> Void
    let onCancel: () -> Void

    private var thumbnailURL: URL? {
        guard let path = countdown.nextVideo.vidThumbUrl else { return nil }
        return serverConfig.fullURL(for: path)
    }

    private var progress: CGFloat {
        let total = CGFloat(VideoDetailReducer.autoPlayCountdownSeconds)
        guard total > 0 else { return 0 }
        return CGFloat(countdown.remainingSeconds) / total
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            HStack(spacing: 14) {
                ZStack {
                    AsyncImage(url: thumbnailURL) { phase in
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

                    Text(countdown.nextVideo.title)
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

            Text("\(countdown.remainingSeconds)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.25), value: countdown.remainingSeconds)
        }
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.5), radius: 6)
    }
}
#endif
