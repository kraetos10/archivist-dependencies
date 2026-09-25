#if os(tvOS)
import ArchivistComponents
import SwiftUI

/// Trailing tile on each tvOS home row that pushes the user into a full
/// paginated list for that section. Laid out like `TVVideoCardView` — a
/// `TVLayout.cardWidth` 16:9 artwork box that takes the shared focus lift,
/// over a hidden info area reserving the card's two-line title and two
/// single-line rows — so in a top-aligned row its artwork lines up with
/// the video and playlist cards beside it.
struct TVHomeViewAllCard: View {
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                artwork
                    .tvCardFocusEffect(isFocused)
                reservedInfoSpace
            }
            .frame(width: TVLayout.cardWidth)
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
                .fill(Color.Surface.highlight)

            VStack(spacing: 12) {
                Image(systemName: "arrow.right.circle.fill")
                    .scaledSystemFont(size: 56, relativeTo: .largeTitle, weight: .semibold)
                    // Decorative: the adjacent label carries the meaning.
                    .accessibilityHidden(true)
                    .foregroundStyle(Color.Accent.dark)
                Text(String.localised("video.viewAll", table: .videos))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Text.primary)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    /// Mirrors `TVVideoCardView.infoView`'s reserved heights. The strings
    /// are non-empty so SwiftUI sizes them at full line height.
    private var reservedInfoSpace: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(" ")
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
            Text(" ").font(.subheadline)
            Text(" ").font(.subheadline)
        }
        .hidden()
    }
}
#endif
