#if os(tvOS)
import ArchivistComponents
import SwiftUI

/// Trailing tile on each tvOS home row that pushes the user into a full
/// paginated list for that section. Sized 16:9 so it sits next to the
/// video/playlist cards without breaking row alignment; the channels row
/// gives it a slightly wider intrinsic frame via its parent.
struct TVHomeViewAllCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.Accent.dark)
                Text(String.localised("video.viewAll", table: .videos))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Text.primary)
            }
            // Match the typical TV video card footprint (16:9 thumb at
            // 400 wide ≈ 225 high, plus title + meta lines). Without an
            // explicit height the 200×200 tile sat well above the card's
            // visual center; sizing it to the card's full extent and
            // letting the inner VStack center its content lands the
            // icon + label aligned with the cards.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.card)
        .frame(width: 280, height: 280)
    }
}
#endif
