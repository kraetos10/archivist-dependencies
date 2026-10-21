import Dependencies
import DependenciesMacros
import Foundation

/// Read-only access to YouTube's Data API v3, using the user's own key.
///
/// Metadata only: nothing here fetches media. The IDs it returns are what
/// `DownloadService.addDownloads` and `ChannelService.subscribeChannels`
/// hand to the user's TubeArchivist server.
///
/// Quota (10,000 units/day on a free key): a search costs 100, everything
/// else 1. So a video search is 101 (search plus one details call for the
/// page), while trending, a channel's uploads and key validation are cheap.
@DependencyClient
public struct YouTubeSearchService: Sendable {
    public var searchVideos: @Sendable (
        _ key: String,
        _ query: String,
        _ order: YouTubeSearchOrder,
        _ filters: YouTubeSearchFilters,
        _ pageToken: String?
    ) async throws -> YouTubePage<YouTubeVideo>
    public var searchPlaylists: @Sendable (
        _ key: String,
        _ query: String,
        _ pageToken: String?
    ) async throws -> YouTubePage<YouTubePlaylist>
    public var searchChannels: @Sendable (
        _ key: String,
        _ query: String,
        _ pageToken: String?
    ) async throws -> YouTubePage<YouTubeChannel>
    /// `categoryId` is one of YouTube's video category IDs (10 is Music), or
    /// `nil` for the overall chart. A chart a region doesn't have comes back empty.
    public var trending: @Sendable (
        _ key: String,
        _ regionCode: String?,
        _ categoryId: String?,
        _ pageToken: String?
    ) async throws -> YouTubePage<YouTubeVideo>
    public var channelUploads: @Sendable (
        _ key: String,
        _ channelId: String,
        _ pageToken: String?
    ) async throws -> YouTubePage<YouTubeVideo>
    public var channelDetails: @Sendable (
        _ key: String,
        _ channelId: String
    ) async throws -> YouTubeChannel
    /// One unit. Throws `YouTubeError.invalidKey` / `.apiNotEnabled` for the
    /// two ways a freshly created key typically fails.
    public var validateKey: @Sendable (
        _ key: String
    ) async throws -> Void
}

extension YouTubeSearchService: DependencyKey {
    static let pageSize = 25

    public static let liveValue = YouTubeSearchService(
        searchVideos: { key, query, order, filters, pageToken in
            // The clock is only needed for an upload window.
            let earliest: Date? = {
                guard filters.uploaded != .any else { return nil }
                @Dependency(\.date.now) var now
                return filters.uploaded.earliest(relativeTo: now)
            }()
            let search = try await YouTubeClient.get(
                SearchListResponse.self,
                endpoint: "search",
                key: key,
                queryItems: [
                    URLQueryItem(name: "part", value: "snippet"),
                    URLQueryItem(name: "type", value: "video"),
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "order", value: order.rawValue),
                    URLQueryItem(name: "videoDuration", value: filters.duration.apiValue),
                    URLQueryItem(
                        name: "publishedAfter",
                        value: earliest?.formatted(.iso8601)
                    ),
                    URLQueryItem(name: "maxResults", value: "\(pageSize)"),
                    URLQueryItem(name: "pageToken", value: pageToken)
                ]
            )
            let ids = search.items.compactMap(\.id.videoId)
            let videos = try await YouTubeClient.videos(ids: ids, key: key)
            return YouTubePage(items: videos, nextPageToken: search.nextPageToken)
        },
        searchPlaylists: { key, query, pageToken in
            let search = try await YouTubeClient.get(
                SearchListResponse.self,
                endpoint: "search",
                key: key,
                queryItems: [
                    URLQueryItem(name: "part", value: "snippet"),
                    URLQueryItem(name: "type", value: "playlist"),
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "maxResults", value: "\(pageSize)"),
                    URLQueryItem(name: "pageToken", value: pageToken)
                ]
            )
            let ids = search.items.compactMap(\.id.playlistId)
            let playlists = try await YouTubeClient.playlists(ids: ids, key: key)
            return YouTubePage(items: playlists, nextPageToken: search.nextPageToken)
        },
        searchChannels: { key, query, pageToken in
            let search = try await YouTubeClient.get(
                SearchListResponse.self,
                endpoint: "search",
                key: key,
                queryItems: [
                    URLQueryItem(name: "part", value: "snippet"),
                    URLQueryItem(name: "type", value: "channel"),
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "maxResults", value: "\(pageSize)"),
                    URLQueryItem(name: "pageToken", value: pageToken)
                ]
            )
            let ids = search.items.compactMap(\.id.channelId)
            let channels = try await YouTubeClient.channels(ids: ids, key: key)
            return YouTubePage(items: channels, nextPageToken: search.nextPageToken)
        },
        trending: { key, regionCode, categoryId, pageToken in
            do {
                let response = try await YouTubeClient.get(
                    VideoListResponse.self,
                    endpoint: "videos",
                    key: key,
                    queryItems: [
                        URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
                        URLQueryItem(name: "chart", value: "mostPopular"),
                        URLQueryItem(name: "regionCode", value: regionCode),
                        URLQueryItem(name: "videoCategoryId", value: categoryId),
                        URLQueryItem(name: "maxResults", value: "\(pageSize)"),
                        URLQueryItem(name: "pageToken", value: pageToken)
                    ]
                )
                return YouTubePage(
                    items: response.items.compactMap(\.video),
                    nextPageToken: response.nextPageToken
                )
            } catch YouTubeError.notFound {
                return YouTubePage(items: [])
            }
        },
        channelUploads: { key, channelId, pageToken in
            // A channel's uploads playlist ID is its channel ID with the
            // `UC` prefix swapped for `UU`. Listing it costs 1 unit, where
            // a channel-filtered `search` costs 100.
            guard channelId.hasPrefix("UC") else { throw YouTubeError.rejected("Unrecognised channel ID") }
            let uploadsId = "UU" + channelId.dropFirst(2)
            let items = try await YouTubeClient.get(
                PlaylistItemListResponse.self,
                endpoint: "playlistItems",
                key: key,
                queryItems: [
                    URLQueryItem(name: "part", value: "contentDetails"),
                    URLQueryItem(name: "playlistId", value: uploadsId),
                    URLQueryItem(name: "maxResults", value: "\(pageSize)"),
                    URLQueryItem(name: "pageToken", value: pageToken)
                ]
            )
            let videos = try await YouTubeClient.videos(
                ids: items.items.map(\.contentDetails.videoId),
                key: key
            )
            return YouTubePage(items: videos, nextPageToken: items.nextPageToken)
        },
        channelDetails: { key, channelId in
            guard let channel = try await YouTubeClient.channels(ids: [channelId], key: key).first else {
                throw YouTubeError.rejected("Channel not found")
            }
            return channel
        },
        validateKey: { key in
            // Any cheap, public lookup will do; it only has to reach the
            // API with this key.
            _ = try await YouTubeClient.get(
                VideoListResponse.self,
                endpoint: "videos",
                key: key,
                queryItems: [
                    URLQueryItem(name: "part", value: "id"),
                    URLQueryItem(name: "id", value: "dQw4w9WgXcQ")
                ]
            )
        }
    )

    public static var testValue: YouTubeSearchService { YouTubeSearchService() }
}

extension DependencyValues {
    public var youTubeSearchService: YouTubeSearchService {
        get { self[YouTubeSearchService.self] }
        set { self[YouTubeSearchService.self] = newValue }
    }
}

// MARK: - Transport

enum YouTubeClient {
    static func get<T: Decodable & Sendable>(
        _ type: T.Type,
        endpoint: String,
        key: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.googleapis.com"
        components.path = "/youtube/v3/\(endpoint)"
        components.queryItems = queryItems.filter { $0.value != nil }
        guard let url = components.url else { throw YouTubeError.network }

        var request = URLRequest(url: url)
        // In a header rather than `?key=`, so the key stays out of any URL
        // that gets logged.
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")

        @Dependency(\.urlSession) var urlSession
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw YouTubeError.network
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YouTubeError(statusCode: http.statusCode, body: data)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw YouTubeError.decodingFailed
        }
    }

    /// Details for `ids`, in the order given. IDs the API doesn't return
    /// (private or deleted videos) are dropped.
    static func videos(
        ids: [String],
        key: String
    ) async throws -> [YouTubeVideo] {
        guard !ids.isEmpty else { return [] }
        let response = try await get(
            VideoListResponse.self,
            endpoint: "videos",
            key: key,
            queryItems: [
                URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
                URLQueryItem(name: "id", value: ids.joined(separator: ","))
            ]
        )
        let byId = Dictionary(
            response.items.compactMap { item in item.video.map { (item.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        return ids.compactMap { byId[$0] }
    }

    static func playlists(
        ids: [String],
        key: String
    ) async throws -> [YouTubePlaylist] {
        guard !ids.isEmpty else { return [] }
        let response = try await get(
            PlaylistListResponse.self,
            endpoint: "playlists",
            key: key,
            queryItems: [
                URLQueryItem(name: "part", value: "snippet,contentDetails"),
                URLQueryItem(name: "id", value: ids.joined(separator: ","))
            ]
        )
        let byId = Dictionary(
            response.items.map { ($0.id, $0.playlist) },
            uniquingKeysWith: { first, _ in first }
        )
        return ids.compactMap { byId[$0] }
    }

    static func channels(
        ids: [String],
        key: String
    ) async throws -> [YouTubeChannel] {
        guard !ids.isEmpty else { return [] }
        let response = try await get(
            ChannelListResponse.self,
            endpoint: "channels",
            key: key,
            queryItems: [
                URLQueryItem(name: "part", value: "snippet,statistics"),
                URLQueryItem(name: "id", value: ids.joined(separator: ","))
            ]
        )
        let byId = Dictionary(
            response.items.map { ($0.id, $0.channel) },
            uniquingKeysWith: { first, _ in first }
        )
        return ids.compactMap { byId[$0] }
    }
}

// MARK: - Wire format

struct SearchListResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        struct Identifier: Decodable, Sendable {
            let videoId: String?
            let channelId: String?
            let playlistId: String?
        }

        let id: Identifier
    }

    let items: [Item]
    let nextPageToken: String?
}

struct PlaylistItemListResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        struct Details: Decodable, Sendable {
            let videoId: String
        }

        let contentDetails: Details
    }

    let items: [Item]
    let nextPageToken: String?
}

struct VideoListResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        struct Snippet: Decodable, Sendable {
            let title: String
            let channelId: String
            let channelTitle: String
            let publishedAt: String?
            let thumbnails: Thumbnails?
        }

        struct ContentDetails: Decodable, Sendable {
            let duration: String?
        }

        struct Statistics: Decodable, Sendable {
            let viewCount: String?
        }

        let id: String
        let snippet: Snippet?
        let contentDetails: ContentDetails?
        let statistics: Statistics?

        /// `nil` when the API sent no snippet (the key-validation call asks
        /// for `id` only).
        var video: YouTubeVideo? {
            guard let snippet else { return nil }
            return YouTubeVideo(
                videoId: id,
                title: snippet.title,
                channelId: snippet.channelId,
                channelTitle: snippet.channelTitle,
                thumbnailURL: snippet.thumbnails?.best,
                published: PublishedDate.date(from: snippet.publishedAt),
                durationSeconds: contentDetails?.duration.flatMap(ISO8601Duration.seconds),
                viewCount: statistics?.viewCount.flatMap { Int($0) }
            )
        }
    }

    let items: [Item]
    let nextPageToken: String?
}

struct PlaylistListResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        struct Snippet: Decodable, Sendable {
            let title: String
            let channelTitle: String?
            let thumbnails: Thumbnails?
        }

        struct ContentDetails: Decodable, Sendable {
            let itemCount: Int?
        }

        let id: String
        let snippet: Snippet
        let contentDetails: ContentDetails?

        var playlist: YouTubePlaylist {
            YouTubePlaylist(
                playlistId: id,
                title: snippet.title,
                channelTitle: snippet.channelTitle ?? "",
                thumbnailURL: snippet.thumbnails?.best,
                itemCount: contentDetails?.itemCount
            )
        }
    }

    let items: [Item]
}

struct ChannelListResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        struct Snippet: Decodable, Sendable {
            let title: String
            let description: String?
            let thumbnails: Thumbnails?
        }

        struct Statistics: Decodable, Sendable {
            let subscriberCount: String?
            let videoCount: String?
            let hiddenSubscriberCount: Bool?
        }

        let id: String
        let snippet: Snippet
        let statistics: Statistics?

        var channel: YouTubeChannel {
            YouTubeChannel(
                channelId: id,
                title: snippet.title,
                channelDescription: snippet.description ?? "",
                thumbnailURL: snippet.thumbnails?.best,
                subscriberCount: statistics?.hiddenSubscriberCount == true
                    ? nil
                    : statistics?.subscriberCount.flatMap { Int($0) },
                videoCount: statistics?.videoCount.flatMap { Int($0) }
            )
        }
    }

    let items: [Item]
}

struct Thumbnails: Decodable, Sendable {
    struct Thumbnail: Decodable, Sendable {
        let url: String
    }

    let maxres: Thumbnail?
    let standard: Thumbnail?
    let high: Thumbnail?
    let medium: Thumbnail?
    let `default`: Thumbnail?

    /// The sharpest size sent. `medium` is only 320x180, which is soft on a
    /// card this wide; `maxres` is 1280x720 but missing on older videos.
    var best: URL? {
        (maxres ?? standard ?? high ?? medium ?? `default`).flatMap { URL(string: $0.url) }
    }
}

/// Parses the `PT1H2M3S` durations the API sends.
enum ISO8601Duration {
    static func seconds(_ raw: String) -> Int? {
        guard raw.hasPrefix("P") else { return nil }
        var total = 0
        var number = ""
        var inTime = false
        for character in raw.dropFirst() {
            switch character {
            case "T":
                inTime = true
            case "0"..."9":
                number.append(character)
            case "D", "H", "M", "S":
                guard let value = Int(number) else { return nil }
                number = ""
                switch (character, inTime) {
                case ("D", false): total += value * 86_400
                case ("H", true): total += value * 3_600
                case ("M", true): total += value * 60
                case ("S", true): total += value
                default: return nil
                }
            default:
                return nil
            }
        }
        return total
    }
}
