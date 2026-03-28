#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct VideoListEmptyState: View {
    public let isSearchActive: Bool
    public let isSearching: Bool
    public let watchFilter: WatchFilter

    public init(
        isSearchActive: Bool,
        isSearching: Bool,
        watchFilter: WatchFilter
    ) {
        self.isSearchActive = isSearchActive
        self.isSearching = isSearching
        self.watchFilter = watchFilter
    }

    @ViewBuilder
    public var body: some View {
        if isSearchActive && !isSearching {
            EmptyStateView(
                icon: "magnifyingglass",
                title: String.localised("video.empty.noResults", table: .videos),
                description: String.localised("video.empty.noSearchMatch", table: .videos)
            )
        } else {
            switch watchFilter {
            case .all:
                EmptyStateView(
                    icon: "play.rectangle.on.rectangle",
                    title: String.localised("video.empty.noVideos", table: .videos),
                    description: String.localised("video.empty.channelDescription", table: .videos)
                )
            case .unwatched:
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: String.localised("video.empty.noUnwatched", table: .videos),
                    description: String.localised("video.empty.allWatched", table: .videos)
                )
            case .watched:
                EmptyStateView(
                    icon: "eye",
                    title: String.localised("video.empty.noWatched", table: .videos),
                    description: String.localised("video.empty.watchDescription", table: .videos)
                )
            case .continueWatching:
                EmptyStateView(
                    icon: "play.circle",
                    title: String.localised("video.empty.noContinueWatching", table: .videos),
                    description: String.localised("video.empty.continueWatchingDescription", table: .videos)
                )
            case .downloaded:
                EmptyStateView(
                    icon: "arrow.down.circle",
                    title: String.localised("video.empty.noDownloads", table: .videos),
                    description: String.localised("video.empty.downloadDescription", table: .videos)
                )
            }
        }
    }
}
#endif
