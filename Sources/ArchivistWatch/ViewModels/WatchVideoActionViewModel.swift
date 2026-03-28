#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchVideoActionViewModel {
    public var isDownloading = false
    public var message: String?

    private let video: VideoResponse
    private let config: ServerConfig
    private let videoService: any VideoServiceType
    private let storage = WatchAudioStorage()
    private let downloadManager = WatchDownloadManager.shared

    public var progress: Double {
        downloadManager.progress
    }

    public var isAlreadyDownloaded: Bool {
        storage.isDownloaded(videoId: video.videoId)
    }

    public var title: String { video.title }
    public var duration: String? { video.durationStr }
    public var fileSize: String? { video.formattedFileSize }

    public init(
        video: VideoResponse,
        config: ServerConfig,
        videoService: any VideoServiceType = VideoService()
    ) {
        self.video = video
        self.config = config
        self.videoService = videoService
    }

    public func downloadAudio() async {
        isDownloading = true
        message = nil

        do {
            let fullVideo = try await videoService.getVideo(
                config: config,
                id: video.videoId
            )

            guard let mediaUrl = fullVideo.mediaUrl else {
                message = String(localized: "action.downloadFailed", bundle: Bundle.module)
                isDownloading = false
                return
            }

            let item = WatchDownloadItem(
                videoId: fullVideo.videoId,
                title: fullVideo.title,
                channelName: fullVideo.channelName,
                mediaUrl: mediaUrl,
                duration: fullVideo.player?.duration.map { Int($0) },
                durationStr: fullVideo.durationStr,
                thumbPath: fullVideo.vidThumbUrl
            )
            try await downloadManager.downloadAudio(
                video: item,
                config: config
            )
            message = String(localized: "action.downloadSuccess", bundle: Bundle.module)
        } catch {
            message = String(localized: "action.downloadFailed", bundle: Bundle.module)
        }
        isDownloading = false
    }
}
#endif
