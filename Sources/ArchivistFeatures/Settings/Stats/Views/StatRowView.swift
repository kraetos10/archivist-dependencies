import ArchivistComponents
import SwiftUI

struct StatRowView: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        #if os(tvOS)
        Button {} label: {
            content
        }
        .buttonStyle(.plain)
        #else
        content
        #endif
    }

    private var content: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.Accent.dark)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
        }
    }
}
