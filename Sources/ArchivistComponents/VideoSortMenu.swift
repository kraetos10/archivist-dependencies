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
            Label(String.localised("video.sort", table: .videos), systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(Color.Text.primary)
                .padding(6)
                .background(Color.Surface.highlight)
                .clipShape(Circle())
                // Small visible disc, full-size tap target.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
    }
}
#endif
