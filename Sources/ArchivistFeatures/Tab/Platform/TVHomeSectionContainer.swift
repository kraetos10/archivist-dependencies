#if os(tvOS)
import ArchivistComponents
import SwiftUI

/// Shared chrome for tvOS home rows. Matches the iOS `HomeFilterSection`
/// pattern: rounded `Surface.highlight` card, leading icon + title header,
/// trailing "View All" link with chevron. Each row's actual carousel is
/// supplied via the `content` closure so this stays purely visual.
struct TVHomeSectionContainer<Content: View>: View {
    let title: String
    let icon: String
    var onViewAll: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: icon)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                if let onViewAll {
                    Button(action: onViewAll) {
                        HStack(spacing: 6) {
                            Text(String.localised("video.viewAll", table: .videos))
                            Image(systemName: "chevron.right")
                        }
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Accent.dark)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 32)

            content()
                .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Surface.highlight)
        )
        .padding(.horizontal, 48)
        .focusSection()
    }
}
#endif
