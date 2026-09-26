#if os(tvOS)
import SwiftUI

/// Shared tvOS metrics, so a card is the same size on every screen and
/// the focus engine sees rows and grids that line up.
///
/// Screen content already sits inside the system's overscan safe area
/// (80pt left/right, 60pt top/bottom on a 1920×1080 canvas), so screens
/// add no horizontal padding of their own on top of it.
public enum TVLayout {
    /// Width of every video and playlist card, in rows and grids alike.
    public static let cardWidth: CGFloat = 400
    /// Width of a channel card (avatar and name).
    public static let channelCardWidth: CGFloat = 250
    /// Diameter of the avatar on a channel card.
    public static let channelAvatarSize: CGFloat = 120
    /// Height of 16:9 card artwork at `cardWidth`.
    public static var cardArtworkHeight: CGFloat { cardWidth * 9 / 16 }
    /// Gap between cards, horizontally and vertically.
    public static let cardSpacing: CGFloat = 48
    /// Vertical room around a horizontal row so a lifted card isn't clipped.
    public static let rowVerticalPadding: CGFloat = 30
    /// Gap between a section's header and its content.
    public static let sectionHeaderSpacing: CGFloat = 16
    /// Corner radius of card artwork.
    public static let cornerRadius: CGFloat = 12

    /// Grid of fixed-width video/playlist cards: four columns inside the
    /// 1760pt safe width, top-aligned so cards of different heights line up.
    public static let cardGridColumns = [
        GridItem(
            .adaptive(minimum: cardWidth, maximum: cardWidth),
            spacing: cardSpacing,
            alignment: .top
        )
    ]

    /// Grid of fixed-width channel cards.
    public static let channelGridColumns = [
        GridItem(
            .adaptive(minimum: channelCardWidth, maximum: channelCardWidth),
            spacing: cardSpacing,
            alignment: .top
        )
    ]
}

/// The focus treatment for every tvOS card: the artwork lifts and casts a
/// shadow while the text beneath it stays put, as in the system lockups.
/// Apply it to the artwork only — never the whole card — and drive it from
/// the card's own `@FocusState`.
public struct TVCardFocusEffect: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(isFocused ? 0.9 : 0), lineWidth: 4)
            }
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? 0.55 : 0),
                radius: isFocused ? 24 : 0,
                y: isFocused ? 16 : 0
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

public extension View {
    /// Lifts this card artwork while `isFocused`. See `TVCardFocusEffect`.
    /// Pass half the artwork's width as `cornerRadius` for circular artwork.
    func tvCardFocusEffect(
        _ isFocused: Bool,
        cornerRadius: CGFloat = TVLayout.cornerRadius
    ) -> some View {
        modifier(TVCardFocusEffect(isFocused: isFocused, cornerRadius: cornerRadius))
    }
}
#endif
