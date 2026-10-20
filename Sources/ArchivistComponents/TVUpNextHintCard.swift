#if os(tvOS)
import SwiftUI

/// The next video, in the last stretch of the current one: thumbnail, title
/// and channel in a card at the bottom-right of the player. Down on the
/// remote focuses it, Select plays it now, and Up or Menu goes back to the
/// video.
struct TVUpNextHintCard: View {
    let item: UpNextItem
    /// The model wants focus on the card.
    let isFocusing: Bool
    let onSelect: () -> Void
    let onExit: () -> Void

    @FocusState private var isFocused: Bool

    private static let artworkWidth: CGFloat = 260
    private static var artworkHeight: CGFloat { artworkWidth * 9 / 16 }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 20) {
                artwork
                    .tvCardFocusEffect(isFocused)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String.localised("video.upNext", table: .videos))
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.channelName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(width: 320, alignment: .leading)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: TVLayout.cornerRadius + 8))
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
        .onChange(of: isFocusing) { _, focusing in
            // The card is already on screen; focus can move onto it now.
            Task { @MainActor in isFocused = focusing }
        }
        .onMoveCommand { direction in
            if direction == .up { onExit() }
        }
        .onExitCommand(perform: onExit)
    }

    private var artwork: some View {
        AsyncImage(url: item.thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(.white.opacity(0.15))
            }
        }
        .frame(width: Self.artworkWidth, height: Self.artworkHeight)
        .overlay(alignment: .bottomTrailing) {
            if let duration = item.duration {
                Text(duration)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
    }
}
#endif
