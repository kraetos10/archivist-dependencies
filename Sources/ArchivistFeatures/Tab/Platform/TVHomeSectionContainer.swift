#if os(tvOS)
import ArchivistComponents
import SwiftUI

/// Shared chrome for tvOS home rows: a leading icon + title header over
/// the row's carousel, supplied via `content`. No background is drawn.
///
/// The header is plain text on purpose. A focusable "View All" link
/// pinned to the far right caught Up presses from the right-hand cards of
/// the row below; each row's trailing `TVHomeViewAllCard` covers it.
struct TVHomeSectionContainer<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TVLayout.sectionHeaderSpacing) {
            Label(title, systemImage: icon)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }
}
#endif
