#if os(watchOS)
import SwiftUI

public struct WatchNowPlayingTab: View {
    let nowPlayingState = WatchNowPlayingState.shared

    public init() {}

    public var body: some View {
        if let player = nowPlayingState.activePlayer {
            WatchNowPlayingView(viewModel: player)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(String(localized: "nowPlaying.empty", bundle: Bundle.module))
                    .font(.headline)
                Text(String(localized: "nowPlaying.emptyDescription", bundle: Bundle.module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
#endif
