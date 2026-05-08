import SwiftUI

// MARK: - Action Pill Label

public struct ActionPillLabel: View {
    let systemImage: String
    let label: String

    public init(
        systemImage: String,
        label: String
    ) {
        self.systemImage = systemImage
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline)
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(Color.Text.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.Surface.highlight)
        .clipShape(Capsule())
    }
}

// MARK: - Download Pill

public struct DownloadPill: View {
    let isDownloading: Bool
    let isDownloaded: Bool
    let downloadProgress: CGFloat
    let onDownload: () -> Void
    let onDeleteDownload: () -> Void
    let onDeleteFromServer: () -> Void

    public init(
        isDownloading: Bool,
        isDownloaded: Bool,
        downloadProgress: CGFloat,
        onDownload: @escaping () -> Void,
        onDeleteDownload: @escaping () -> Void,
        onDeleteFromServer: @escaping () -> Void
    ) {
        self.isDownloading = isDownloading
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.onDownload = onDownload
        self.onDeleteDownload = onDeleteDownload
        self.onDeleteFromServer = onDeleteFromServer
    }

    public var body: some View {
        if isDownloading {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.Brand.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                    Circle()
                        .trim(from: 0, to: downloadProgress)
                        .stroke(Color.Accent.dark, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(-90))
                }
                Text(String.localised("video.downloadToDevice", table: .videos))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color.Text.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.Surface.highlight)
            .clipShape(Capsule())
        } else {
            Menu {
                if isDownloaded {
                    Button(role: .destructive) {
                        #if !os(tvOS)
                        HapticFeedback.warning.play()
                        #endif
                        onDeleteDownload()
                    } label: {
                        Label(String.localised("video.deleteDownload", table: .videos), systemImage: "internaldrive")
                    }
                } else {
                    Button {
                        #if !os(tvOS)
                        HapticFeedback.medium.play()
                        #endif
                        onDownload()
                    } label: {
                        Label(
                            String.localised("video.downloadToDevice", table: .videos),
                            systemImage: "arrow.down.circle"
                        )
                    }
                }
                Button(role: .destructive) {
                    #if !os(tvOS)
                    HapticFeedback.warning.play()
                    #endif
                    onDeleteFromServer()
                } label: {
                    Label(String.localised("video.deleteFromServer", table: .videos), systemImage: "trash")
                }
            } label: {
                ActionPillLabel(systemImage: "ellipsis", label: "")
            }
        }
    }
}

// MARK: - Action Buttons Row

public struct ActionButtonsRow: View {
    let likes: String?
    let dislikes: String?
    let isWatched: Bool
    let showPlayNext: Bool
    let isInPlayNext: Bool
    let youtubeURL: URL?
    let tubeArchivistURL: URL?
    let isDownloading: Bool
    let isDownloaded: Bool
    let downloadProgress: CGFloat
    let onToggleWatched: () -> Void
    let onAddToPlayNext: () -> Void
    let onAddToPlaylist: () -> Void
    let onDownload: () -> Void
    let onDeleteDownload: () -> Void
    let onDeleteFromServer: () -> Void

    public init(
        likes: String?,
        dislikes: String?,
        isWatched: Bool,
        showPlayNext: Bool,
        isInPlayNext: Bool,
        youtubeURL: URL?,
        tubeArchivistURL: URL? = nil,
        isDownloading: Bool,
        isDownloaded: Bool,
        downloadProgress: CGFloat,
        onToggleWatched: @escaping () -> Void,
        onAddToPlayNext: @escaping () -> Void,
        onAddToPlaylist: @escaping () -> Void,
        onDownload: @escaping () -> Void,
        onDeleteDownload: @escaping () -> Void,
        onDeleteFromServer: @escaping () -> Void
    ) {
        self.likes = likes
        self.dislikes = dislikes
        self.isWatched = isWatched
        self.showPlayNext = showPlayNext
        self.isInPlayNext = isInPlayNext
        self.youtubeURL = youtubeURL
        self.tubeArchivistURL = tubeArchivistURL
        self.isDownloading = isDownloading
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.onToggleWatched = onToggleWatched
        self.onAddToPlayNext = onAddToPlayNext
        self.onAddToPlaylist = onAddToPlaylist
        self.onDownload = onDownload
        self.onDeleteDownload = onDeleteDownload
        self.onDeleteFromServer = onDeleteFromServer
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let likes {
                    ActionPillLabel(systemImage: "hand.thumbsup", label: likes)
                }

                if let dislikes {
                    ActionPillLabel(systemImage: "hand.thumbsdown", label: dislikes)
                }

                Button {
                    #if !os(tvOS)
                    HapticFeedback.selection.play()
                    #endif
                    onToggleWatched()
                } label: {
                    ActionPillLabel(
                        systemImage: isWatched ? "eye.fill" : "eye",
                        label: isWatched
                            ? String.localised("video.markAsUnwatched", table: .videos)
                            : String.localised("video.markAsWatched", table: .videos)
                    )
                }

                if !isInPlayNext {
                    Button {
                        onAddToPlayNext()
                    } label: {
                        ActionPillLabel(
                            systemImage: "text.line.last.and.arrowtriangle.forward",
                            label: String.localised("video.playNext", table: .videos)
                        )
                    }
                }

                Button {
                    #if !os(tvOS)
                    HapticFeedback.selection.play()
                    #endif
                    onAddToPlaylist()
                } label: {
                    ActionPillLabel(
                        systemImage: "text.badge.plus",
                        label: String.localised("video.addToPlaylist", table: .videos)
                    )
                }

                #if !os(tvOS)
                if youtubeURL != nil || tubeArchivistURL != nil {
                    Menu {
                        if let youtubeURL {
                            ShareLink(item: youtubeURL) {
                                Label(
                                    String.localised("video.share.youtube", table: .videos),
                                    systemImage: "play.rectangle"
                                )
                            }
                        }
                        if let tubeArchivistURL {
                            ShareLink(item: tubeArchivistURL) {
                                Label(
                                    String.localised("video.share.tubeArchivist", table: .videos),
                                    systemImage: "server.rack"
                                )
                            }
                        }
                    } label: {
                        ActionPillLabel(
                            systemImage: "arrowshape.turn.up.right",
                            label: String.localised("generic.share", table: .generic)
                        )
                    }
                }
                #endif

                DownloadPill(
                    isDownloading: isDownloading,
                    isDownloaded: isDownloaded,
                    downloadProgress: downloadProgress,
                    onDownload: onDownload,
                    onDeleteDownload: onDeleteDownload,
                    onDeleteFromServer: onDeleteFromServer
                )
            }
        }
    }
}
