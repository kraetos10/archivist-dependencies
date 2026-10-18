import ArchivistNetworking
import ComposableArchitecture

@Reducer
public enum VideoListPath {
    case videoDetail(VideoDetailReducer)
    case filteredList(FilteredVideoListReducer)
    /// The Queue strip's View All: the Queue screen itself.
    case queue(DownloadsReducer)
}

extension VideoListPath.State: Equatable, Sendable {}
