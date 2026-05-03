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

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)

            HStack(spacing: 16) {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Color.Brand.secondary.opacity(0.3))
                    }
                }
                .frame(width: 128, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text(String.localised("video.upNext", table: .videos))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(countdown.nextVideo.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(
                        String(
                            format: String.localised(
                                "video.autoPlayCountdown",
                                table: .videos
                            ),
                            countdown.remainingSeconds
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    Button(action: onPlayNow) {
                        Label(
                            String.localised("video.autoPlayPlayNow", table: .videos),
                            systemImage: "play.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onCancel) {
                        Text(String.localised("generic.cancel", table: .generic))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }
}
#endif
