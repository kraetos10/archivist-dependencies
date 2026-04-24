#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct VideoContextMenu: View {
    public let youtubeURL: URL?
    public let isDownloaded: Bool
    public let isWatched: Bool
    public let onPlayNext: (() -> Void)?
    public let onAddToPlaylist: () -> Void
    public let onDownloadToDevice: () -> Void
    public let onDeleteFromDevice: (() -> Void)?
    public let onToggleWatched: () -> Void
    public let onDeleteFromServer: () -> Void

    public init(
        youtubeURL: URL?,
        isDownloaded: Bool = false,
        isWatched: Bool = false,
        onPlayNext: (() -> Void)? = nil,
        onAddToPlaylist: @escaping () -> Void,
        onDownloadToDevice: @escaping () -> Void,
        onDeleteFromDevice: (() -> Void)? = nil,
        onToggleWatched: @escaping () -> Void,
        onDeleteFromServer: @escaping () -> Void
    ) {
        self.youtubeURL = youtubeURL
        self.isDownloaded = isDownloaded
        self.isWatched = isWatched
        self.onPlayNext = onPlayNext
        self.onAddToPlaylist = onAddToPlaylist
        self.onDownloadToDevice = onDownloadToDevice
        self.onDeleteFromDevice = onDeleteFromDevice
        self.onToggleWatched = onToggleWatched
        self.onDeleteFromServer = onDeleteFromServer
    }

    public var body: some View {
        if let onPlayNext {
            Button {
                HapticFeedback.selection.play()
                onPlayNext()
            } label: {
                Label(
                    String.localised("video.playNext", table: .videos),
                    systemImage: "text.line.first.and.arrowtriangle.forward"
                )
            }
        }
        if let youtubeURL {
            ShareLink(item: youtubeURL) {
                Label(String.localised("generic.share", table: .generic), systemImage: "square.and.arrow.up")
            }
        }
        Button {
            HapticFeedback.selection.play()
            onAddToPlaylist()
        } label: {
            Label(String.localised("video.addToPlaylist", table: .videos), systemImage: "text.badge.plus")
        }
        if isDownloaded, let onDeleteFromDevice {
            Button(role: .destructive) {
                HapticFeedback.warning.play()
                onDeleteFromDevice()
            } label: {
                Label(String.localised("video.deleteDownload", table: .videos), systemImage: "trash.circle")
            }
        } else {
            Button {
                HapticFeedback.medium.play()
                onDownloadToDevice()
            } label: {
                Label(String.localised("video.downloadToDevice", table: .videos), systemImage: "arrow.down.circle")
            }
        }
        Button {
            HapticFeedback.selection.play()
            onToggleWatched()
        } label: {
            Label(
                isWatched
                    ? String.localised("video.markAsUnwatched", table: .videos)
                    : String.localised("video.markAsWatched", table: .videos),
                systemImage: isWatched ? "eye.slash" : "eye"
            )
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
