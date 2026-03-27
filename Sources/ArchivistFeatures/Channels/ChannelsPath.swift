import ArchivistNetworking
import ComposableArchitecture

@Reducer
public enum ChannelsPath {
    case channelDetail(ChannelDetailReducer)
}

extension ChannelsPath.State: Sendable {}
