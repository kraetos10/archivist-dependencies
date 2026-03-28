#if os(watchOS)
import Foundation
import SQLiteData
import StructuredQueries

@Table
public struct WatchDownload: Identifiable, Equatable, Sendable {
    @Column(primaryKey: true) public var id: String
    public var title: String
    public var channelName: String
    public var duration: Int?
    public var durationStr: String?
    public var fileSize: Int?
    public var downloadedAt: Double
    public var lastPlayedPosition: Double = 0
    public var thumbPath: String?
}
#endif
