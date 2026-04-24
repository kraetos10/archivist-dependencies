import ArchivistNetworking
import ComposableArchitecture

@Reducer
public enum VideoListPath {
    case videoDetail(VideoDetailReducer)
    case filteredList(FilteredVideoListReducer)
}

extension VideoListPath.State: Sendable {}
