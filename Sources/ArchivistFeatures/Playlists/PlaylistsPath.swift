import ArchivistNetworking
import ComposableArchitecture

@Reducer
public enum PlaylistsPath {
    case playlistDetail(PlaylistDetailReducer)
}

extension PlaylistsPath.State: Sendable {}
extension PlaylistsPath.State: Equatable {}
