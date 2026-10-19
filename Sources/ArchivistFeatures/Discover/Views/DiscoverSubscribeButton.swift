#if !os(tvOS)
import ArchivistComponents
import SwiftUI

struct DiscoverSubscribeButton: View {
    let isSubscribed: Bool
    let isPending: Bool
    let action: () -> Void

    var body: some View {
        if isSubscribed {
            Label(
                String.localised("discover.subscribed", table: .discover),
                systemImage: "checkmark"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.Brand.secondary)
        } else {
            Button(action: action) {
                Group {
                    if isPending {
                        ProgressView()
                    } else {
                        Text(String.localised("discover.subscribe", table: .discover))
                    }
                }
                .font(.footnote.weight(.semibold))
                .frame(minWidth: 84)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.Accent.dark)
            .disabled(isPending)
        }
    }
}
#endif
