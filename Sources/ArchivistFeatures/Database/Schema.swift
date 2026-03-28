import ArchivistNetworking
import Foundation
internal import SQLiteData
import StructuredQueries

// MARK: - Device Downloads

@Table
public struct DeviceDownload: Identifiable, Equatable, Sendable {
    @Column(primaryKey: true) public var id: String
    var title: String
    var channelName: String
    var thumbUrl: String?
    var status: DeviceDownloadStatus?
    var progress: Double = 0
    var fileSize: Int?
    var downloadedAt: Double?
    var createdAt: Double
}

public enum DeviceDownloadStatus: Int, QueryBindable, Sendable {
    case downloading = 0
    case completed = 1
    case failed = 2
}

// MARK: - Play Next Queue

@Table
public struct PlayNextItem: Identifiable, Equatable, Sendable {
    public let id: Int
    var videoId: String
    var title: String
    var channelName: String
    var thumbUrl: String?
    var duration: String?
    var addedAt: Double
}

// MARK: - Server Connection

@Table
public struct ServerConnection: Identifiable, Equatable, Sendable {
    @Column(primaryKey: true) public var id: Int = 1
    public var serverAddress: String = ""
    public var port: String = ""
    public var useHTTP: Bool = false
}
