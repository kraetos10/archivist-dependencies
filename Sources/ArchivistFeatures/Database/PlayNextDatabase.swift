import ArchivistNetworking
import Dependencies
import Foundation
internal import SQLiteData
import StructuredQueries

public struct PlayNextDatabase: Sendable {
    var addToQueue: @Sendable (VideoResponse) async throws -> Void
    var removeFromQueue: @Sendable (Int) async throws -> Void
    public var clearQueue: @Sendable () async throws -> Void
    var popNext: @Sendable () async throws -> PlayNextItem?
    /// Returns the next queue item without removing it. Used by the
    /// autoplay countdown — the row only gets popped if the countdown
    /// actually fires the autoplay (or the user taps "Play now"). If
    /// they cancel the countdown, the item stays queued for next time.
    var peekNext: @Sendable () async throws -> PlayNextItem?
}

extension PlayNextDatabase: DependencyKey {
    public static var liveValue: PlayNextDatabase {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date) var date

        return PlayNextDatabase(
            addToQueue: { video in
                try database.write { db in
                    try PlayNextItem
                        .insert {
                            PlayNextItem.Draft(
                                videoId: video.videoId,
                                title: video.title,
                                channelName: video.channelName,
                                thumbUrl: video.vidThumbUrl,
                                duration: video.durationStr,
                                published: video.published,
                                addedAt: date.now.timeIntervalSince1970
                            )
                        }
                        .execute(db)
                }
            },
            removeFromQueue: { id in
                try database.write { db in
                    try PlayNextItem.find(id).delete().execute(db)
                }
            },
            clearQueue: {
                try database.write { db in
                    try PlayNextItem.delete().execute(db)
                }
            },
            popNext: {
                try database.write { db in
                    guard let first = try PlayNextItem
                        .order(by: \.id)
                        .fetchOne(db)
                    else { return nil }
                    try PlayNextItem.find(first.id).delete().execute(db)
                    return first
                }
            },
            peekNext: {
                try database.read { db in
                    try PlayNextItem
                        .order(by: \.id)
                        .fetchOne(db)
                }
            }
        )
    }

    /// An empty queue that accepts every write.
    public static var testValue: PlayNextDatabase {
        PlayNextDatabase(
            addToQueue: { _ in },
            removeFromQueue: { _ in },
            clearQueue: {},
            popNext: { nil },
            peekNext: { nil }
        )
    }

    public static var previewValue: PlayNextDatabase { testValue }
}

extension DependencyValues {
    public var playNextDatabase: PlayNextDatabase {
        get { self[PlayNextDatabase.self] }
        set { self[PlayNextDatabase.self] = newValue }
    }
}
