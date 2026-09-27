#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// The All / Unwatched filter pills above the channel grid.
@ViewAction(for: ChannelsReducer.self)
struct ChannelsFilterRow: View {
    let store: StoreOf<ChannelsReducer>

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ChannelsFilterPill(
                    label: String.localised("generic.all", table: .generic),
                    icon: "line.3.horizontal.decrease.circle",
                    isSelected: store.filter == .all
                ) {
                    send(.filterChanged(.all), animation: .default)
                }

                ChannelsFilterPill(
                    label: String.localised("generic.unwatched", table: .generic),
                    icon: "eye.slash",
                    isSelected: store.filter == .withUnwatched
                ) {
                    send(.filterChanged(.withUnwatched), animation: .default)
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String.localised("login.channelFilter", table: .login))
    }
}

private struct ChannelsFilterPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.Brand.primary : Color.Text.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.Text.primary : Color.Surface.highlight)
                .clipShape(.capsule)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
