import Dependencies

extension DependencyValues {
    public var videoService: VideoService {
        get { self[VideoService.self] }
        set { self[VideoService.self] = newValue }
    }

    public var channelService: ChannelService {
        get { self[ChannelService.self] }
        set { self[ChannelService.self] = newValue }
    }

    public var playlistService: PlaylistService {
        get { self[PlaylistService.self] }
        set { self[PlaylistService.self] = newValue }
    }

    public var downloadService: DownloadService {
        get { self[DownloadService.self] }
        set { self[DownloadService.self] = newValue }
    }

    public var searchService: SearchService {
        get { self[SearchService.self] }
        set { self[SearchService.self] = newValue }
    }

    public var statsService: StatsService {
        get { self[StatsService.self] }
        set { self[StatsService.self] = newValue }
    }

    public var taskService: TaskService {
        get { self[TaskService.self] }
        set { self[TaskService.self] = newValue }
    }

    public var userService: UserService {
        get { self[UserService.self] }
        set { self[UserService.self] = newValue }
    }

    public var pingService: PingService {
        get { self[PingService.self] }
        set { self[PingService.self] = newValue }
    }

    public var keychainService: KeychainService {
        get { self[KeychainService.self] }
        set { self[KeychainService.self] = newValue }
    }

    public var localVideoStorage: LocalVideoStorage {
        get { self[LocalVideoStorage.self] }
        set { self[LocalVideoStorage.self] = newValue }
    }

    public var healthService: HealthService {
        get { self[HealthService.self] }
        set { self[HealthService.self] = newValue }
    }
}
