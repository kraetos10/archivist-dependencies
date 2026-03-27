import Dependencies

// MARK: - Video Service

extension DependencyValues {
    public var videoService: VideoServiceType {
        get { self[VideoServiceKey.self] }
        set { self[VideoServiceKey.self] = newValue }
    }
}

private enum VideoServiceKey: DependencyKey {
    static var liveValue: VideoServiceType { VideoService() }
    static var testValue: VideoServiceType { VideoService() }
}

// MARK: - Channel Service

extension DependencyValues {
    public var channelService: ChannelServiceType {
        get { self[ChannelServiceKey.self] }
        set { self[ChannelServiceKey.self] = newValue }
    }
}

private enum ChannelServiceKey: DependencyKey {
    static var liveValue: ChannelServiceType { ChannelService() }
    static var testValue: ChannelServiceType { ChannelService() }
}

// MARK: - Playlist Service

extension DependencyValues {
    public var playlistService: PlaylistServiceType {
        get { self[PlaylistServiceKey.self] }
        set { self[PlaylistServiceKey.self] = newValue }
    }
}

private enum PlaylistServiceKey: DependencyKey {
    static var liveValue: PlaylistServiceType { PlaylistService() }
    static var testValue: PlaylistServiceType { PlaylistService() }
}

// MARK: - Download Service

extension DependencyValues {
    public var downloadService: DownloadServiceType {
        get { self[DownloadServiceKey.self] }
        set { self[DownloadServiceKey.self] = newValue }
    }
}

private enum DownloadServiceKey: DependencyKey {
    static var liveValue: DownloadServiceType { DownloadService() }
    static var testValue: DownloadServiceType { DownloadService() }
}

// MARK: - Search Service

extension DependencyValues {
    public var searchService: SearchServiceType {
        get { self[SearchServiceKey.self] }
        set { self[SearchServiceKey.self] = newValue }
    }
}

private enum SearchServiceKey: DependencyKey {
    static var liveValue: SearchServiceType { SearchService() }
    static var testValue: SearchServiceType { SearchService() }
}

// MARK: - Stats Service

extension DependencyValues {
    public var statsService: StatsServiceType {
        get { self[StatsServiceKey.self] }
        set { self[StatsServiceKey.self] = newValue }
    }
}

private enum StatsServiceKey: DependencyKey {
    static var liveValue: StatsServiceType { StatsService() }
    static var testValue: StatsServiceType { StatsService() }
}

// MARK: - Task Service

extension DependencyValues {
    public var taskService: TaskServiceType {
        get { self[TaskServiceKey.self] }
        set { self[TaskServiceKey.self] = newValue }
    }
}

private enum TaskServiceKey: DependencyKey {
    static var liveValue: TaskServiceType { TaskService() }
    static var testValue: TaskServiceType { TaskService() }
}

// MARK: - User Service

extension DependencyValues {
    public var userService: UserServiceType {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

private enum UserServiceKey: DependencyKey {
    static var liveValue: UserServiceType { UserService() }
    static var testValue: UserServiceType { UserService() }
}

// MARK: - Ping Service

extension DependencyValues {
    public var pingService: PingServiceType {
        get { self[PingServiceKey.self] }
        set { self[PingServiceKey.self] = newValue }
    }
}

private enum PingServiceKey: DependencyKey {
    static var liveValue: PingServiceType { PingService() }
    static var testValue: PingServiceType { PingService() }
}

// MARK: - Keychain Service

extension DependencyValues {
    public var keychainService: KeychainServiceType {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }
}

private enum KeychainServiceKey: DependencyKey {
    static var liveValue: KeychainServiceType { KeychainService() }
    static var testValue: KeychainServiceType { KeychainService() }
}

// MARK: - Local Video Storage

extension DependencyValues {
    public var localVideoStorage: LocalVideoStorageType {
        get { self[LocalVideoStorageKey.self] }
        set { self[LocalVideoStorageKey.self] = newValue }
    }
}

private enum LocalVideoStorageKey: DependencyKey {
    static var liveValue: LocalVideoStorageType { LocalVideoStorage() }
    static var testValue: LocalVideoStorageType { LocalVideoStorage() }
}

// MARK: - Video Download Manager

extension DependencyValues {
    public var videoDownloadManager: VideoDownloadManagerType {
        get { self[VideoDownloadManagerKey.self] }
        set { self[VideoDownloadManagerKey.self] = newValue }
    }
}

private enum VideoDownloadManagerKey: DependencyKey {
    static var liveValue: VideoDownloadManagerType { VideoDownloadManager() }
    static var testValue: VideoDownloadManagerType { VideoDownloadManager() }
}

// MARK: - Health Service

extension DependencyValues {
    public var healthService: HealthServiceType {
        get { self[HealthServiceKey.self] }
        set { self[HealthServiceKey.self] = newValue }
    }
}

private enum HealthServiceKey: DependencyKey {
    static var liveValue: HealthServiceType { HealthService() }
    static var testValue: HealthServiceType { HealthService() }
}
