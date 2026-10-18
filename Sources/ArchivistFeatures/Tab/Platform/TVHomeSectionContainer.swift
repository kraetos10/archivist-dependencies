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
    /// A line under the title, for a row that needs explaining.
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TVLayout.sectionHeaderSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Text.primary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }
}
#endif
