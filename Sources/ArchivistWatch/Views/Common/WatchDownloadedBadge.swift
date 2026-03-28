#if os(watchOS)
import SwiftUI

public struct WatchDownloadedBadge: View {
    let videoId: String
    private let storage = WatchAudioStorage()

    public init(videoId: String) {
        self.videoId = videoId
    }

    public var body: some View {
        if storage.isDownloaded(videoId: videoId) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.green)
        }
    }
}
#endif
