#if os(iOS) || os(tvOS)
import SwiftUI

/// A small capsule saying a SponsorBlock segment was just skipped. Sits at
/// the top of the player and never takes touches or focus.
struct SponsorSkipBanner: View {
    private let notice = SponsorSkipNotice.shared

    var body: some View {
        VStack {
            if notice.isVisible {
                Label {
                    Text(String.localised("video.sponsorBlock.skipped", table: .videos))
                } icon: {
                    Image(systemName: "forward.end.fill")
                        .accessibilityHidden(true)
                }
                #if os(tvOS)
                .font(.callout)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                #else
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                #endif
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.25), value: notice.isVisible)
        .allowsHitTesting(false)
    }
}
#endif
