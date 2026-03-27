import Foundation

public nonisolated protocol VideoServiceType: Sendable {
    func getVideos(
        config: ServerConfig,
        page: Int,
        sort: String?,
        order: String?,
        type: String?,
        watch: String?,
        channel: String?,
        playlist: String?
    ) async throws -> PaginatedResponse<VideoResponse>
    func getVideo(config: ServerConfig, id: String) async throws -> VideoResponse
    func deleteVideo(config: ServerConfig, id: String) async throws
    func getComments(config: ServerConfig, videoId: String) async throws -> [VideoComment]
    func getSimilar(config: ServerConfig, videoId: String) async throws -> [VideoResponse]
    func getNav(config: ServerConfig, videoId: String) async throws -> VideoNavResponse
    func setProgress(config: ServerConfig, videoId: String, position: Int) async throws
    func deleteProgress(config: ServerConfig, videoId: String) async throws
    func setWatched(config: ServerConfig, videoId: String, isWatched: Bool) async throws
}

public nonisolated struct VideoComment: Decodable, Sendable, Equatable {
    public let commentId: String?
    public let commentText: String?
    public let commentTimestamp: Int?
    public let commentLikeCount: Int?
    public let commentIsFavorited: Bool?
    public let commentAuthor: String?
    public let commentAuthorId: String?

    public var relativeDate: String? {
        guard let commentTimestamp else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(commentTimestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    public init(
        commentId: String?, commentText: String?, commentTimestamp: Int?,
        commentLikeCount: Int?, commentIsFavorited: Bool?,
        commentAuthor: String?, commentAuthorId: String?
    ) {
        self.commentId = commentId
        self.commentText = commentText
        self.commentTimestamp = commentTimestamp
        self.commentLikeCount = commentLikeCount
        self.commentIsFavorited = commentIsFavorited
        self.commentAuthor = commentAuthor
        self.commentAuthorId = commentAuthorId
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
        case commentLikeCount = "comment_like_count"
        case commentIsFavorited = "comment_is_favorited"
        case commentAuthor = "comment_author"
        case commentAuthorId = "comment_author_id"
    }
}

public nonisolated struct VideoNavResponse: Decodable, Sendable, Equatable {
    public let playlist: String?
    public let index: Int?
    public let previous: String?
    public let next: String?

    public init(playlist: String?, index: Int?, previous: String?, next: String?) {
        self.playlist = playlist
        self.index = index
        self.previous = previous
        self.next = next
    }
}

public nonisolated struct VideoService: VideoServiceType {
    public init() {}

    public func getVideos(
        config: ServerConfig,
        page: Int = 1,
        sort: String? = nil,
        order: String? = nil,
        type: String? = nil,
        watch: String? = nil,
        channel: String? = nil,
        playlist: String? = nil
    ) async throws -> PaginatedResponse<VideoResponse> {
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
    }

    public func getVideo(config: ServerConfig, id: String) async throws -> VideoResponse {
        let request = NetworkAPIRequest<VideoResponse>(
            config: config,
            path: .video(id: id)
        )
        return try await request.execute().data
    }

    public func deleteVideo(config: ServerConfig, id: String) async throws {
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .video(id: id),
            method: .delete
        )
        _ = try await request.execute()
    }

    public func getComments(config: ServerConfig, videoId: String) async throws -> [VideoComment] {
        let request = NetworkAPIRequest<[VideoComment]>(
            config: config,
            path: .videoComments(id: videoId)
        )
        return try await request.execute().data
    }

    public func getSimilar(config: ServerConfig, videoId: String) async throws -> [VideoResponse] {
        let request = NetworkAPIRequest<[VideoResponse]>(
            config: config,
            path: .videoSimilar(id: videoId)
        )
        return try await request.execute().data
    }

    public func getNav(config: ServerConfig, videoId: String) async throws -> VideoNavResponse {
        let request = NetworkAPIRequest<VideoNavResponse>(
            config: config,
            path: .videoNav(id: videoId)
        )
        return try await request.execute().data
    }

    public func setProgress(config: ServerConfig, videoId: String, position: Int) async throws {
        let body = try JSONEncoder().encode(VideoProgressRequest(position: position))
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .videoProgress(id: videoId),
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func deleteProgress(config: ServerConfig, videoId: String) async throws {
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .videoProgress(id: videoId),
            method: .delete
        )
        _ = try await request.execute()
    }

    public func setWatched(config: ServerConfig, videoId: String, isWatched: Bool) async throws {
        let body = try JSONEncoder().encode(WatchedRequest(id: videoId, isWatched: isWatched))
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .watched,
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }
}

public nonisolated struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
