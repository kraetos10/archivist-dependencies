import ArchivistNetworking
import ComposableArchitecture

@Reducer
public enum VideoListPath {
    case videoDetail(VideoDetailReducer)
}

extension VideoListPath.State: Sendable {}
