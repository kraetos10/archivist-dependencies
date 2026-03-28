import ArchivistNetworking
import SwiftUI

public struct WatchFilterRow: View {
    public let watchFilter: WatchFilter
    public let onFilterChanged: (WatchFilter) -> Void

    public init(
        watchFilter: WatchFilter,
        onFilterChanged: @escaping (WatchFilter) -> Void
    ) {
        self.watchFilter = watchFilter
        self.onFilterChanged = onFilterChanged
    }

    private var availableFilters: [WatchFilter] {
        #if os(tvOS)
        WatchFilter.allCases.filter { $0 != .downloaded }
        #else
        WatchFilter.allCases
        #endif
    }

    public var body: some View {
        #if os(tvOS)
        HStack(spacing: filterSpacing) {
            ForEach(availableFilters, id: \.self) { filter in
                let isSelected = watchFilter == filter
                Button {
                    onFilterChanged(filter)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(iconFont)
                        Text(filter.label)
                    }
                    .font(labelFont)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.Brand.primary : Color.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, verticalPadding)
                    .background(isSelected ? Color.Text.primary : Color.Surface.highlight)
                    .clipShape(Capsule())
                }
                .buttonStyle(TVCapsuleButtonStyle())

                Spacer()
            }
        }
        .padding(.horizontal, contentMargin)
        #else
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: filterSpacing) {
                ForEach(availableFilters, id: \.self) { filter in
                    let isSelected = watchFilter == filter
                    Button {
                        HapticFeedback.selection.play()
                        onFilterChanged(filter)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(iconFont)
                            Text(filter.label)
                        }
                        .font(labelFont)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.Brand.primary : Color.Text.primary)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .background(isSelected ? Color.Text.primary : Color.Surface.highlight)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .contentMargins(.horizontal, contentMargin)
        #endif
    }

    #if os(tvOS)
    private var filterSpacing: CGFloat { 16 }
    private var iconFont: Font { .body }
    private var labelFont: Font { .headline }
    private var horizontalPadding: CGFloat { 24 }
    private var verticalPadding: CGFloat { 12 }
    private var contentMargin: CGFloat { 48 }
    #else
    private var filterSpacing: CGFloat { 8 }
    private var iconFont: Font { .caption }
    private var labelFont: Font { .subheadline }
    private var horizontalPadding: CGFloat { 14 }
    private var verticalPadding: CGFloat { 6 }
    private var contentMargin: CGFloat { 16 }
    #endif
}

#if os(tvOS)
public struct TVCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
#endif
