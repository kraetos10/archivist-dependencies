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

            if let info = store.autoPlayCountdownInfo {
                AutoPlayCountdownOverlay(
                    info: info,
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
            if let thumbURL = store.thumbnailURL {
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
                .scaledSystemFont(size: 64, relativeTo: .largeTitle)
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
        // A bare `onTapGesture` carries no accessibility traits, so
        // VoiceOver saw the thumbnail as static art with no way to start
        // playback. Collapse the stack into one button element instead.
        .accessibilityElement()
        .accessibilityLabel(String.localised("video.playVideo", table: .videos))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            HapticFeedback.light.play()
            send(.playTapped)
        }
    }

    func thumbnailPlaceholder(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.Brand.secondary.opacity(0.3))
            .frame(height: height)
    }
}
#endif
