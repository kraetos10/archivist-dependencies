#if os(watchOS)
import SwiftUI

public struct WatchNowPlayingTab: View {
    let nowPlaying: WatchNowPlayingState

    public init(nowPlaying: WatchNowPlayingState) {
        self.nowPlaying = nowPlaying
    }

    public var body: some View {
        if let player = nowPlaying.activePlayer {
            WatchNowPlayingView(viewModel: player)
        } else {
            ContentUnavailableView {
                Label(String(localized: "nowPlaying.empty", bundle: .module), systemImage: "waveform")
            } description: {
                Text(String(localized: "nowPlaying.emptyDescription", bundle: .module))
            }
        }
    }
}
#endif
