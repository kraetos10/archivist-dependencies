import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct VideoService: Sendable {
    public var getVideos: @Sendable (
        _ config: ServerConfig,
        _ page: Int,
        _ sort: String?,
        _ order: String?,
        _ type: String?,
        _ watch: String?,
        _ channel: String?,
        _ playlist: String?
    ) async throws -> PaginatedResponse<VideoResponse>
    public var getVideo: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> VideoResponse
    public var deleteVideo: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> Void
    public var getComments: @Sendable (
        _ config: ServerConfig,
        _ videoId: String
    ) async throws -> [VideoComment]
    public var getSimilar: @Sendable (
        _ config: ServerConfig,
        _ videoId: String
    ) async throws -> [VideoResponse]
    public var getNav: @Sendable (
        _ config: ServerConfig,
        _ videoId: String
    ) async throws -> VideoNavResponse
    public var setProgress: @Sendable (
        _ config: ServerConfig,
        _ videoId: String,
        _ position: Int
    ) async throws -> Void
    public var deleteProgress: @Sendable (
        _ config: ServerConfig,
        _ videoId: String
    ) async throws -> Void
    public var setWatched: @Sendable (
        _ config: ServerConfig,
        _ videoId: String,
        _ isWatched: Bool
    ) async throws -> Void
}

extension VideoService: DependencyKey {
    public static let liveValue = VideoService(
        getVideos: { config, page, sort, order, type, watch, channel, playlist in
            var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
            if let sort { queryItems.append(URLQueryItem(name: "sort", value: sort)) }
            if let order { queryItems.append(URLQueryItem(name: "order", value: order)) }
            if let type { queryItems.append(URLQueryItem(name: "type", value: type)) }
            if let watch { queryItems.append(URLQueryItem(name: "watch", value: watch)) }
            if let channel { queryItems.append(URLQueryItem(name: "channel", value: channel)) }
            if let playlist { queryItems.append(URLQueryItem(name: "playlist", value: playlist)) }

            let request = NetworkAPIRequest<PaginatedResponse<VideoResponse>>(
                config: config,
                path: .videoList,
                queryItems: queryItems
            )
            return try await request.execute().data
        },
        getVideo: { config, id in
            let request = NetworkAPIRequest<VideoResponse>(
                config: config,
                path: .video(id: id)
            )
            return try await request.execute().data
        },
        deleteVideo: { config, id in
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .video(id: id),
                method: .delete
            )
            _ = try await request.execute()
        },
        getComments: { config, videoId in
            let request = NetworkAPIRequest<[VideoComment]>(
                config: config,
                path: .videoComments(id: videoId)
            )
            return try await request.execute().data
        },
        getSimilar: { config, videoId in
            let request = NetworkAPIRequest<[VideoResponse]>(
                config: config,
                path: .videoSimilar(id: videoId)
            )
            return try await request.execute().data
        },
        getNav: { config, videoId in
            let request = NetworkAPIRequest<VideoNavResponse>(
                config: config,
                path: .videoNav(id: videoId)
            )
            return try await request.execute().data
        },
        setProgress: { config, videoId, position in
            let body = try JSONEncoder().encode(VideoProgressRequest(position: position))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .videoProgress(id: videoId),
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        deleteProgress: { config, videoId in
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .videoProgress(id: videoId),
                method: .delete
            )
            _ = try await request.execute()
        },
        setWatched: { config, videoId, isWatched in
            let body = try JSONEncoder().encode(WatchedRequest(id: videoId, isWatched: isWatched))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .watched,
                method: .post,
                body: body
            )
            _ = try await request.execute()
        }
    )

    public static var testValue: VideoService { VideoService() }
}

/// A comment, with its replies nested under it. The server builds the
/// thread from each comment's `comment_parent` ("root" at the top), so
/// `commentReplies` holds full comments of the same shape.
public nonisolated struct VideoComment: Decodable, Sendable, Equatable {
    public let commentId: String?
    public let commentText: String?
    public let commentTimestamp: Int?
    public let commentLikeCount: Int?
    public let commentIsFavorited: Bool?
    public let commentAuthor: String?
    public let commentAuthorId: String?
    public let commentAuthorIsUploader: Bool?
    public let commentAuthorThumbnail: String?
    public let commentParent: String?
    /// Optional so a payload without it, or an older server, still decodes;
    /// read `replies`.
    public let commentReplies: [VideoComment]?

    public var relativeDate: String? {
        guard let commentTimestamp else { return nil }
        return PublishedDate.relative(Date(timeIntervalSince1970: TimeInterval(commentTimestamp)))
    }

    public var replies: [VideoComment] {
        commentReplies ?? []
    }

    /// Every reply under this comment, depth first. YouTube threads are one
    /// level deep, but nothing in the format stops a reply to a reply; those
    /// flatten into the same list rather than indenting further.
    public var flattenedReplies: [VideoComment] {
        replies.flatMap { [$0] + $0.flattenedReplies }
    }

    public var replyCount: Int {
        flattenedReplies.count
    }

    public var isByUploader: Bool {
        commentAuthorIsUploader == true
    }

    /// The author's avatar, hosted by YouTube. It can have expired since
    /// the comments were archived, so views fall back to `authorInitial`.
    public var authorThumbnailURL: URL? {
        commentAuthorThumbnail.flatMap(URL.init(string:))
    }

    /// First letter of the author's name, skipping the "@" of a handle.
    public var authorInitial: String {
        let name = (commentAuthor ?? "").drop { $0 == "@" }
        return name.first.map { String($0).uppercased() } ?? "?"
    }

    public init(
        commentId: String?,
        commentText: String?,
        commentTimestamp: Int?,
        commentLikeCount: Int?,
        commentIsFavorited: Bool?,
        commentAuthor: String?,
        commentAuthorId: String?,
        commentAuthorIsUploader: Bool? = nil,
        commentAuthorThumbnail: String? = nil,
        commentParent: String? = nil,
        commentReplies: [VideoComment]? = nil
    ) {
        self.commentId = commentId
        self.commentText = commentText
        self.commentTimestamp = commentTimestamp
        self.commentLikeCount = commentLikeCount
        self.commentIsFavorited = commentIsFavorited
        self.commentAuthor = commentAuthor
        self.commentAuthorId = commentAuthorId
        self.commentAuthorIsUploader = commentAuthorIsUploader
        self.commentAuthorThumbnail = commentAuthorThumbnail
        self.commentParent = commentParent
        self.commentReplies = commentReplies
    }

    public static let placeholder = VideoComment(
        commentId: "placeholder",
        commentText: "This is a placeholder comment text that spans multiple lines for loading.",
        commentTimestamp: nil,
        commentLikeCount: 12,
        commentIsFavorited: false,
        commentAuthor: "Placeholder Author",
        commentAuthorId: nil
    )

    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case commentText = "comment_text"
        case commentTimestamp = "comment_timestamp"
        case commentLikeCount = "comment_likecount"
        case commentIsFavorited = "comment_is_favorited"
        case commentAuthor = "comment_author"
        case commentAuthorId = "comment_author_id"
        case commentAuthorIsUploader = "comment_author_is_uploader"
        case commentAuthorThumbnail = "comment_author_thumbnail"
        case commentParent = "comment_parent"
        case commentReplies = "comment_replies"
    }
}

extension VideoComment: Identifiable {
    /// The server's comment id; author and timestamp stand in for the rare
    /// comment without one.
    public var id: String {
        commentId ?? "\(commentAuthorId ?? commentAuthor ?? "")-\(commentTimestamp ?? 0)"
    }
}

extension Array where Element == VideoComment {
    /// Comments and every reply under them, for the section's count.
    public var totalCommentCount: Int {
        count + reduce(0) { $0 + $1.replyCount }
    }
}

public nonisolated struct VideoNavResponse: Decodable, Sendable, Equatable {
    public let playlist: String?
    public let index: Int?
    public let previous: String?
    public let next: String?

    public init(
        playlist: String?,
        index: Int?,
        previous: String?,
        next: String?
    ) {
        self.playlist = playlist
        self.index = index
        self.previous = previous
        self.next = next
    }
}

public nonisolated struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
