#if os(watchOS)
@testable import ArchivistNetworking
@testable import ArchivistWatch
import Foundation

enum WatchFixtures {
    static let config = ServerConfig(baseURL: "tube.example.com", apiToken: "token")

    static func paginate(
        page: Int,
        lastPage: Int
    ) -> PaginatedResponse<VideoResponse>.PaginateInfo {
        .init(
            pageSize: 12,
            pageFrom: 0,
            currentPage: page,
            lastPage: lastPage,
            totalHits: 0,
            nextPages: [],
            prevPages: nil,
            maxHits: false,
            params: nil
        )
    }

    static func video(_ id: String) -> VideoResponse {
        VideoResponse(
            videoId: id,
            title: "Video \(id)",
            description: nil,
            category: nil,
            channel: .placeholder,
            published: nil,
            dateDownloaded: nil,
            vidLastRefresh: nil,
            vidThumbUrl: "/cache/\(id).jpg",
            vidType: .videos,
            active: true,
            mediaUrl: "/media/\(id).mp4",
            mediaSize: nil,
            player: nil,
            stats: nil,
            subtitles: nil,
            streams: nil,
            tags: nil,
            commentCount: nil
        )
    }

    static func videoPage(
        _ ids: [String],
        page: Int = 1,
        lastPage: Int = 1
    ) -> PaginatedResponse<VideoResponse> {
        PaginatedResponse(data: ids.map(video), paginate: paginate(page: page, lastPage: lastPage))
    }

    static func download(_ id: String) -> DownloadResponse {
        DownloadResponse(
            youtubeId: id,
            title: "Download \(id)",
            channelId: "UC1",
            channelName: "Channel",
            channelIndexed: true,
            status: .pending,
            vidType: .videos,
            duration: nil,
            published: nil,
            timestamp: nil,
            vidThumbUrl: nil,
            message: nil
        )
    }

    static func downloadPage(
        _ ids: [String],
        page: Int = 1,
        lastPage: Int = 1
    ) -> PaginatedResponse<DownloadResponse> {
        PaginatedResponse(
            data: ids.map(download),
            paginate: .init(
                pageSize: 12,
                pageFrom: 0,
                currentPage: page,
                lastPage: lastPage,
                totalHits: 0,
                nextPages: [],
                prevPages: nil,
                maxHits: false,
                params: nil
            )
        )
    }

    static func temporaryStorage() -> WatchAudioStorage {
        WatchAudioStorage(
            directory: URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        )
    }

    @MainActor
    static func playback(
        catalog: WatchDownloadCatalog = WatchDownloadCatalog(),
        storage: WatchAudioStorage = temporaryStorage(),
        videoService: VideoService = VideoService()
    ) -> WatchPlaybackServices {
        WatchPlaybackServices(
            nowPlaying: WatchNowPlayingState(),
            downloadManager: WatchDownloadManager(
                sessionIdentifier: "tests.\(UUID().uuidString)",
                catalog: catalog,
                storage: storage
            ),
            catalog: catalog,
            storage: storage,
            videoService: videoService
        )
    }
}

struct TestError: Error {}
#endif
