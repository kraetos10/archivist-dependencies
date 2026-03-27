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
                Label(String.localised("video.playNext", table: .videos), systemImage: "text.line.first.and.arrowtriangle.forward")
            }
        }
        ShareLink(item: youtubeURL) {
            Label(String.localised("generic.share"), systemImage: "square.and.arrow.up")
        }
        Button {
            HapticFeedback.selection.play()
            onAddToPlaylist()
        } label: {
            Label(String.localised("video.addToPlaylist", table: .videos), systemImage: "text.badge.plus")
        }
        Button {
            HapticFeedback.medium.play()
            onDownloadToDevice()
        } label: {
            Label(String.localised("video.downloadToDevice", table: .videos), systemImage: "arrow.down.circle")
        }
        Button {
            HapticFeedback.selection.play()
            onMarkAsWatched()
        } label: {
            Label(String.localised("video.markAsWatched", table: .videos), systemImage: "eye")
        }
        Button(role: .destructive) {
            HapticFeedback.warning.play()
            onDeleteFromServer()
        } label: {
            Label(String.localised("video.deleteFromServer", table: .videos), systemImage: "trash")
        }
    }
}
#endif
