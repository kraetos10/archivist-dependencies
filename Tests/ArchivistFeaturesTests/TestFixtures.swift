import ArchivistNetworking
import IdentifiedCollections

enum TestFixtures {
    static let serverConfig = ServerConfig(
        baseURL: "localhost",
        apiToken: "test-token"
    )

    static let paginateInfoPage1 = PaginatedResponse<ChannelResponse>.PaginateInfo(
        pageSize: 25,
        pageFrom: 0,
        currentPage: 1,
        lastPage: 1,
        totalHits: 2,
        nextPages: [],
        prevPages: nil,
        maxHits: false,
        params: nil
    )

    // MARK: - Channels

    static let channel1 = ChannelResponse(
        channelId: "UC_channel1",
        channelName: "Test Channel 1",
        channelDescription: "A test channel",
        channelSubs: 1000,
        channelActive: true,
        channelSubscribed: true,
        channelTags: nil,
        channelTabs: nil,
        channelOverwrites: nil,
        channelLastRefresh: nil,
        channelBannerUrl: nil,
        channelThumbUrl: nil,
        channelTvartUrl: nil
    )

    static let channel2 = ChannelResponse(
        channelId: "UC_channel2",
        channelName: "Test Channel 2",
        channelDescription: nil,
        channelSubs: 5000,
        channelActive: true,
        channelSubscribed: true,
        channelTags: nil,
        channelTabs: nil,
        channelOverwrites: nil,
        channelLastRefresh: nil,
        channelBannerUrl: nil,
        channelThumbUrl: nil,
        channelTvartUrl: nil
    )

    static let paginatedChannels = PaginatedResponse<ChannelResponse>(
        data: [channel1, channel2],
        paginate: paginateInfoPage1
    )

    static func paginatedChannelsMultiPage(
        page: Int,
        lastPage: Int
    ) -> PaginatedResponse<ChannelResponse> {
        PaginatedResponse<ChannelResponse>(
            data: [channel1, channel2],
            paginate: PaginatedResponse<ChannelResponse>.PaginateInfo(
                pageSize: 25,
                pageFrom: (page - 1) * 25,
                currentPage: page,
                lastPage: lastPage,
                totalHits: lastPage * 2,
                nextPages: page < lastPage ? [page + 1] : [],
                prevPages: page > 1 ? [page - 1] : nil,
                maxHits: false,
                params: nil
            )
        )
    }

    // MARK: - Playlists

    static let playlist1 = PlaylistResponse(
        playlistId: "PL_playlist1",
        playlistName: "Test Playlist 1",
        playlistType: .regular,
        playlistChannelId: "UC_channel1",
        playlistChannel: "Test Channel 1",
        playlistDescription: "A test playlist",
        playlistThumbnail: nil,
        playlistSubscribed: true,
        playlistActive: true,
        playlistSortOrder: nil,
        playlistLastRefresh: nil,
        playlistEntries: nil
    )

    static let playlist2 = PlaylistResponse(
        playlistId: "PL_playlist2",
        playlistName: "Test Playlist 2",
        playlistType: .regular,
        playlistChannelId: "UC_channel2",
        playlistChannel: "Test Channel 2",
        playlistDescription: nil,
        playlistThumbnail: nil,
        playlistSubscribed: true,
        playlistActive: true,
        playlistSortOrder: nil,
        playlistLastRefresh: nil,
        playlistEntries: nil
    )

    static let paginatedPlaylists = PaginatedResponse<PlaylistResponse>(
        data: [playlist1, playlist2],
        paginate: PaginatedResponse<PlaylistResponse>.PaginateInfo(
            pageSize: 25,
            pageFrom: 0,
            currentPage: 1,
            lastPage: 1,
            totalHits: 2,
            nextPages: [],
            prevPages: nil,
            maxHits: false,
            params: nil
        )
    )

    static func paginatedPlaylistsMultiPage(
        page: Int,
        lastPage: Int
    ) -> PaginatedResponse<PlaylistResponse> {
        PaginatedResponse<PlaylistResponse>(
            data: [playlist1, playlist2],
            paginate: PaginatedResponse<PlaylistResponse>.PaginateInfo(
                pageSize: 25,
                pageFrom: (page - 1) * 25,
                currentPage: page,
                lastPage: lastPage,
                totalHits: lastPage * 2,
                nextPages: page < lastPage ? [page + 1] : [],
                prevPages: page > 1 ? [page - 1] : nil,
                maxHits: false,
                params: nil
            )
        )
    }

    // MARK: - Playlist with entries (for detail)

    static let playlistEntry1 = PlaylistEntry(
        youtubeId: "video_1",
        title: "Entry Video 1",
        idx: 0,
        uploader: "Test Channel 1",
        vidThumbUrl: nil
    )

    static let playlistEntry2 = PlaylistEntry(
        youtubeId: "video_2",
        title: "Entry Video 2",
        idx: 1,
        uploader: "Test Channel 1",
        vidThumbUrl: nil
    )

    static let playlistWithEntries = PlaylistResponse(
        playlistId: "PL_playlist1",
        playlistName: "Test Playlist 1",
        playlistType: .regular,
        playlistChannelId: "UC_channel1",
        playlistChannel: "Test Channel 1",
        playlistDescription: "A test playlist",
        playlistThumbnail: nil,
        playlistSubscribed: true,
        playlistActive: true,
        playlistSortOrder: nil,
        playlistLastRefresh: nil,
        playlistEntries: [playlistEntry1, playlistEntry2]
    )

    // MARK: - Videos

    static let video1 = VideoResponse(
        videoId: "video_1",
        title: "Test Video 1",
        description: nil,
        category: nil,
        channel: VideoChannel(
            channelId: "UC_channel1",
            channelName: "Test Channel 1",
            channelActive: nil,
            channelBannerUrl: nil,
            channelThumbUrl: nil,
            channelTvartUrl: nil,
            channelDescription: nil,
            channelLastRefresh: nil,
            channelSubs: nil,
            channelSubscribed: nil,
            channelTags: nil,
            channelTabs: nil
        ),
        published: "2025-01-01T00:00:00+00:00",
        dateDownloaded: nil,
        vidLastRefresh: nil,
        vidThumbUrl: nil,
        vidType: nil,
        active: nil,
        mediaUrl: nil,
        mediaSize: nil,
        player: nil,
        stats: nil,
        subtitles: nil,
        streams: nil,
        tags: nil,
        commentCount: nil
    )

    static let video2 = VideoResponse(
        videoId: "video_2",
        title: "Test Video 2",
        description: nil,
        category: nil,
        channel: VideoChannel(
            channelId: "UC_channel1",
            channelName: "Test Channel 1",
            channelActive: nil,
            channelBannerUrl: nil,
            channelThumbUrl: nil,
            channelTvartUrl: nil,
            channelDescription: nil,
            channelLastRefresh: nil,
            channelSubs: nil,
            channelSubscribed: nil,
            channelTags: nil,
            channelTabs: nil
        ),
        published: "2025-01-02T00:00:00+00:00",
        dateDownloaded: nil,
        vidLastRefresh: nil,
        vidThumbUrl: nil,
        vidType: nil,
        active: nil,
        mediaUrl: nil,
        mediaSize: nil,
        player: nil,
        stats: nil,
        subtitles: nil,
        streams: nil,
        tags: nil,
        commentCount: nil
    )

    static let paginatedVideos = PaginatedResponse<VideoResponse>(
        data: [video1, video2],
        paginate: PaginatedResponse<VideoResponse>.PaginateInfo(
            pageSize: 25,
            pageFrom: 0,
            currentPage: 1,
            lastPage: 1,
            totalHits: 2,
            nextPages: [],
            prevPages: nil,
            maxHits: false,
            params: nil
        )
    )

    static let emptyVideos = PaginatedResponse<VideoResponse>(
        data: [],
        paginate: PaginatedResponse<VideoResponse>.PaginateInfo(
            pageSize: 25,
            pageFrom: 0,
            currentPage: 1,
            lastPage: 1,
            totalHits: 0,
            nextPages: [],
            prevPages: nil,
            maxHits: false,
            params: nil
        )
    )

    static func paginatedVideosMultiPage(
        page: Int,
        lastPage: Int
    ) -> PaginatedResponse<VideoResponse> {
        PaginatedResponse<VideoResponse>(
            data: [video1, video2],
            paginate: PaginatedResponse<VideoResponse>.PaginateInfo(
                pageSize: 25,
                pageFrom: (page - 1) * 25,
                currentPage: page,
                lastPage: lastPage,
                totalHits: lastPage * 2,
                nextPages: page < lastPage ? [page + 1] : [],
                prevPages: page > 1 ? [page - 1] : nil,
                maxHits: false,
                params: nil
            )
        )
    }

    // MARK: - Downloads

    static let download1 = DownloadResponse(
        youtubeId: "dl_video_1",
        title: "Pending Download 1",
        channelId: "UC_channel1",
        channelName: "Test Channel 1",
        channelIndexed: true,
        status: .pending,
        vidType: .videos,
        duration: "10:00",
        published: nil,
        timestamp: nil,
        vidThumbUrl: nil,
        message: nil
    )

    static let download2 = DownloadResponse(
        youtubeId: "dl_video_2",
        title: "Pending Download 2",
        channelId: "UC_channel1",
        channelName: "Test Channel 1",
        channelIndexed: true,
        status: .pending,
        vidType: .videos,
        duration: "05:00",
        published: nil,
        timestamp: nil,
        vidThumbUrl: nil,
        message: nil
    )

    static let paginatedDownloads = PaginatedResponse<DownloadResponse>(
        data: [download1, download2],
        paginate: PaginatedResponse<DownloadResponse>.PaginateInfo(
            pageSize: 25,
            pageFrom: 0,
            currentPage: 1,
            lastPage: 1,
            totalHits: 2,
            nextPages: [],
            prevPages: nil,
            maxHits: false,
            params: nil
        )
    )

    static let emptyDownloads = PaginatedResponse<DownloadResponse>(
        data: [],
        paginate: PaginatedResponse<DownloadResponse>.PaginateInfo(
            pageSize: 25,
            pageFrom: 0,
            currentPage: 1,
            lastPage: 1,
            totalHits: 0,
            nextPages: [],
            prevPages: nil,
            maxHits: false,
            params: nil
        )
    )
}
