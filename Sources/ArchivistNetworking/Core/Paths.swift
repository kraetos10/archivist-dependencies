import Foundation

public nonisolated enum Paths {
    // Videos
    case videoList
    case video(id: String)
    case videoComments(id: String)
    case videoSimilar(id: String)
    case videoNav(id: String)
    case videoProgress(id: String)

    // Channels
    case channelList
    case channel(id: String)
    case channelAggs(id: String)
    case channelNav(id: String)
    case channelSearch

    // Playlists
    case playlistList
    case playlist(id: String)
    case playlistCustom
    case playlistCustomAction(id: String)

    // Downloads
    case downloadList
    case download(id: String)
    case downloadAggs

    // Search
    case search

    // Watched
    case watched

    // Refresh
    case refresh

    // Notifications
    case notification

    // Tasks
    case taskById(id: String)
    case taskByName
    case taskByNameSpecific(name: String)
    case taskNotification
    case taskSchedule
    case taskScheduleSpecific(name: String)

    // Stats
    case statsBiggestChannels
    case statsChannel
    case statsDownload
    case statsDownloadHist
    case statsPlaylist
    case statsVideo
    case statsWatch

    // User
    case userAccount
    case userLogin
    case userLogout
    case userMe

    // System
    case health
    case ping

    // Config
    case config
    case cookie
    case snapshot
    case snapshotSpecific(id: String)
    case backup
    case backupSpecific(filename: String)
    case token

    public var rawValue: String {
        switch self {
        case .videoList: "/api/video/"
        case .video(let id): "/api/video/\(id)/"
        case .videoComments(let id): "/api/video/\(id)/comment/"
        case .videoSimilar(let id): "/api/video/\(id)/similar/"
        case .videoNav(let id): "/api/video/\(id)/nav/"
        case .videoProgress(let id): "/api/video/\(id)/progress/"

        case .channelList: "/api/channel/"
        case .channel(let id): "/api/channel/\(id)/"
        case .channelAggs(let id): "/api/channel/\(id)/aggs/"
        case .channelNav(let id): "/api/channel/\(id)/nav/"
        case .channelSearch: "/api/channel/search/"

        case .playlistList: "/api/playlist/"
        case .playlist(let id): "/api/playlist/\(id)/"
        case .playlistCustom: "/api/playlist/custom/"
        case .playlistCustomAction(let id): "/api/playlist/custom/\(id)/"

        case .downloadList: "/api/download/"
        case .download(let id): "/api/download/\(id)/"
        case .downloadAggs: "/api/download/aggs/"

        case .search: "/api/search/"

        case .watched: "/api/watched/"

        case .refresh: "/api/refresh/"

        case .notification: "/api/notification/"

        case .taskById(let id): "/api/task/by-id/\(id)/"
        case .taskByName: "/api/task/by-name/"
        case .taskByNameSpecific(let name): "/api/task/by-name/\(name)/"
        case .taskNotification: "/api/task/notification/"
        case .taskSchedule: "/api/task/schedule/"
        case .taskScheduleSpecific(let name): "/api/task/schedule/\(name)/"

        case .statsBiggestChannels: "/api/stats/biggestchannels/"
        case .statsChannel: "/api/stats/channel/"
        case .statsDownload: "/api/stats/download/"
        case .statsDownloadHist: "/api/stats/downloadhist/"
        case .statsPlaylist: "/api/stats/playlist/"
        case .statsVideo: "/api/stats/video/"
        case .statsWatch: "/api/stats/watch/"

        case .userAccount: "/api/user/account/"
        case .userLogin: "/api/user/login/"
        case .userLogout: "/api/user/logout/"
        case .userMe: "/api/user/me/"

        case .health: "/api/health/"
        case .ping: "/api/ping/"

        case .config: "/api/appsettings/config/"
        case .cookie: "/api/appsettings/cookie/"
        case .snapshot: "/api/appsettings/snapshot/"
        case .snapshotSpecific(let id): "/api/appsettings/snapshot/\(id)/"
        case .backup: "/api/appsettings/backup/"
        case .backupSpecific(let filename): "/api/appsettings/backup/\(filename)/"
        case .token: "/api/appsettings/token/"
        }
    }
}
