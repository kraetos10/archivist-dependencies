import ArchivistComponents
import SwiftUI

/// Warns that the server must run with `DISABLE_STATIC_AUTH=true`. Without
/// it the API key logs in fine but media and thumbnails fail to load, so the
/// notice is styled to be hard to skim past.
struct StaticAuthNoticeView: View {
    let variable: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(String.localised("login.staticAuth.title", table: .login))
                    .font(.headline)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)
            }

            Text(String.localised("login.staticAuth.message", table: .login))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: variable)
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.Brand.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                #if !os(tvOS)
                .textSelection(.enabled)
                #endif
        }
        .foregroundStyle(Color.Text.primary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.Brand.secondary, lineWidth: 2)
        }
    }
}

#Preview {
    StaticAuthNoticeView(variable: "DISABLE_STATIC_AUTH=true")
        .padding()
}
