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
            .frame(width: 200, height: 200)
        }
        .buttonStyle(.card)
    }
}
#endif
