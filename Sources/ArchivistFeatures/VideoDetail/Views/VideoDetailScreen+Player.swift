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

            HStack(spacing: 20) {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Color.Brand.secondary.opacity(0.3))
                    }
                }
                .frame(width: 200, height: 113)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    Text(String.localised("video.upNext", table: .videos))
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)

                    Text(countdown.nextVideo.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Button(action: onPlayNow) {
                            Label(
                                String.localised("video.autoPlayPlayNow", table: .videos),
                                systemImage: "play.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.white, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: onCancel) {
                            Text(String.localised("generic.cancel", table: .generic))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            .white,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: progress)

                    Text("\(countdown.remainingSeconds)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeOut(duration: 0.25), value: countdown.remainingSeconds)
                }
                .frame(width: 88, height: 88)
            }
            .padding(24)
        }
    }
}
#endif
