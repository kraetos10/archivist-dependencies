#if os(tvOS)
import ArchivistComponents
import SwiftUI

/// Trailing tile on each tvOS home row that pushes the user into a full
/// paginated list for that section. It takes the shape of the cards beside
/// it — a 16:9 box in video and playlist rows, a round avatar in the
/// channels row — with explicit sizes, since a horizontal row gives no
/// width for an aspect ratio to work from.
struct TVHomeViewAllCard: View {
    enum Style {
        /// Matches `TVVideoCardView` / `TVPlaylistCardView`.
        case card
        /// Matches `TVChannelCardView`.
        case channel
    }

    var style: Style = .card
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            switch style {
            case .card:
                cardLayout
            case .channel:
                channelLayout
            }
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
        .accessibilityLabel(String.localised("video.viewAll", table: .videos))
    }

    // MARK: - Card

    private var cardLayout: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
                .fill(Color.Surface.highlight)

            VStack(spacing: 12) {
                arrow
                label
            }
        }
        .frame(width: TVLayout.cardWidth, height: TVLayout.cardArtworkHeight)
        .tvCardFocusEffect(isFocused)
    }

    // MARK: - Channel

    private var channelLayout: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.Surface.highlight)
                arrow
            }
            .frame(width: TVLayout.channelAvatarSize, height: TVLayout.channelAvatarSize)
            .tvCardFocusEffect(isFocused, cornerRadius: TVLayout.channelAvatarSize / 2)

            label
                .lineLimit(1)
        }
        .frame(width: TVLayout.channelCardWidth)
    }

    // MARK: - Pieces

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .scaledSystemFont(size: 44, relativeTo: .largeTitle, weight: .semibold)
            .foregroundStyle(Color.Accent.dark)
            // Decorative: the label beside it carries the meaning.
            .accessibilityHidden(true)
    }

    private var label: some View {
        Text(String.localised("video.viewAll", table: .videos))
            .font(.headline)
            .foregroundStyle(Color.Text.primary)
    }
}
#endif
