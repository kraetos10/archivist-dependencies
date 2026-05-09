#if os(tvOS)
import ArchivistComponents
import SwiftUI

/// Trailing tile on each tvOS home row that pushes the user into a full
/// paginated list for that section. Mirrors `TVVideoCardView`'s
/// `VStack(thumbnail, info)` structure — a 16:9 visible tile plus an
/// invisible info area sized to three text lines — so its overall
/// height matches the adjacent video cards exactly. Without that
/// match, `LazyHStack`'s default `.center` alignment lined up the
/// tile's centre with the cards' centres geometrically, but because
/// the tile was a 280×280 square against ~340pt-tall video cards the
/// icon ended up sitting 30pt above the cards' visual centre.
struct TVHomeViewAllCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.Surface.highlight)

                    VStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(Color.Accent.dark)
                        Text(String.localised("video.viewAll", table: .videos))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Text.primary)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)

                // Invisible placeholder matching `TVVideoCardView.infoView`
                // (headline + subheadline + caption with spacing 6) so the
                // overall tile height matches the adjacent cards. Keep the
                // strings non-empty so SwiftUI sizes them at the proper
                // line height instead of collapsing to zero.
                VStack(alignment: .leading, spacing: 6) {
                    Text(" ").font(.headline)
                    Text(" ").font(.subheadline)
                    Text(" ").font(.caption)
                }
                .hidden()
            }
            .frame(width: 280)
        }
        .buttonStyle(.card)
    }
}
#endif
