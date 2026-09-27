#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchChannelDetailView: View {
    let viewModel: WatchChannelDetailViewModel
    let channel: ChannelResponse

    public init(
        viewModel: WatchChannelDetailViewModel,
        channel: ChannelResponse
    ) {
        self.viewModel = viewModel
        self.channel = channel
    }

    public var body: some View {
        WatchVideoListContent(viewModel: viewModel)
            .navigationTitle(channel.channelName)
    }
}
#endif
