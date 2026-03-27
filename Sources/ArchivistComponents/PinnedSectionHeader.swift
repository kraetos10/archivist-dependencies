import SwiftUI

public struct PinnedSectionHeader: View {
    public let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        #if os(tvOS)
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.vertical, 16)
        #else
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.Text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.top, 1)
            .background(
                Color.Brand.primary
                    .ignoresSafeArea(.container, edges: .top)
            )
        #endif
    }
}
