#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct VideoListEmptyState: View {
    public let isSearchActive: Bool
    public let isSearching: Bool
    public let showDownloadedOnly: Bool
    public let watchFilter: WatchFilter

    public init(
        isSearchActive: Bool,
        isSearching: Bool,
        showDownloadedOnly: Bool,
        watchFilter: WatchFilter
    ) {
        self.isSearchActive = isSearchActive
        self.isSearching = isSearching
        self.showDownloadedOnly = showDownloadedOnly
        self.watchFilter = watchFilter
    }

    @ViewBuilder
    public var body: some View {
        if isSearchActive && !isSearching {
            EmptyStateView(
                icon: "magnifyingglass",
                title: String(localized: "No results", bundle: .module),
                description: String(localized: "No videos match your search.", bundle: .module)
            )
        } else if showDownloadedOnly {
            EmptyStateView(
                icon: "arrow.down.circle",
                title: String(localized: "No downloads yet", bundle: .module),
                description: String(localized: "Videos you download will appear here.", bundle: .module)
            )
        } else {
            switch watchFilter {
            case .all:
                EmptyStateView(
                    icon: "play.rectangle.on.rectangle",
                    title: String(localized: "No videos yet", bundle: .module),
                    description: String(localized: "Videos from this channel will appear here.", bundle: .module)
                )
            case .unwatched:
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: String(localized: "No unwatched videos", bundle: .module),
                    description: String(localized: "All videos have been watched.", bundle: .module)
                )
            case .watched:
                EmptyStateView(
                    icon: "eye",
                    title: String(localized: "No watched videos", bundle: .module),
                    description: String(localized: "Videos you watch will appear here.", bundle: .module)
                )
            }
        }
    }
}
#endif
