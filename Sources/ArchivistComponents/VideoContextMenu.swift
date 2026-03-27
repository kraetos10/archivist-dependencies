#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct VideoContextMenu: View {
    public let youtubeURL: URL
    public let onPlayNext: (() -> Void)?
    public let onAddToPlaylist: () -> Void
    public let onDownloadToDevice: () -> Void
    public let onMarkAsWatched: () -> Void
    public let onDeleteFromServer: () -> Void

    public init(
        youtubeURL: URL,
        onPlayNext: (() -> Void)? = nil,
        onAddToPlaylist: @escaping () -> Void,
        onDownloadToDevice: @escaping () -> Void,
        onMarkAsWatched: @escaping () -> Void,
        onDeleteFromServer: @escaping () -> Void
    ) {
        self.youtubeURL = youtubeURL
        self.onPlayNext = onPlayNext
        self.onAddToPlaylist = onAddToPlaylist
        self.onDownloadToDevice = onDownloadToDevice
        self.onMarkAsWatched = onMarkAsWatched
        self.onDeleteFromServer = onDeleteFromServer
    }

    public var body: some View {
        if let onPlayNext {
            Button {
                HapticFeedback.selection.play()
                onPlayNext()
            } label: {
                Label(String(localized: "Play Next", bundle: .module), systemImage: "text.line.first.and.arrowtriangle.forward")
            }
        }
        ShareLink(item: youtubeURL) {
            Label(String(localized: "Share", bundle: .module), systemImage: "square.and.arrow.up")
        }
        Button {
            HapticFeedback.selection.play()
            onAddToPlaylist()
        } label: {
            Label(String(localized: "Add to Playlist", bundle: .module), systemImage: "text.badge.plus")
        }
        Button {
            HapticFeedback.medium.play()
            onDownloadToDevice()
        } label: {
            Label(String(localized: "Download to Device", bundle: .module), systemImage: "arrow.down.circle")
        }
        Button {
            HapticFeedback.selection.play()
            onMarkAsWatched()
        } label: {
            Label(String(localized: "Mark as Watched", bundle: .module), systemImage: "eye")
        }
        Button(role: .destructive) {
            HapticFeedback.warning.play()
            onDeleteFromServer()
        } label: {
            Label(String(localized: "Delete from Server", bundle: .module), systemImage: "trash")
        }
    }
}
#endif
