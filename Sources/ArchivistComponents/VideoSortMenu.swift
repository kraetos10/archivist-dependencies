#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct VideoSortMenu: View {
    public let current: VideoSortOrder
    public let onChanged: (VideoSortOrder) -> Void

    public init(
        current: VideoSortOrder,
        onChanged: @escaping (VideoSortOrder) -> Void
    ) {
        self.current = current
        self.onChanged = onChanged
    }

    public var body: some View {
        Menu {
            ForEach(VideoSortOrder.allCases, id: \.self) { sort in
                Button {
                    onChanged(sort)
                } label: {
                    Label(sort.label, systemImage: sort.icon)
                }
                .disabled(current == sort)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
                .foregroundStyle(Color.Text.primary)
                .padding(6)
                .background(Color.Surface.highlight)
                .clipShape(Circle())
        }
    }
}
#endif
