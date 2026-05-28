import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DownloadService: Sendable {
    public var getDownloads: @Sendable (
        _ config: ServerConfig,
        _ page: Int,
        _ filter: String?,
        _ channel: String?,
        _ query: String?,
        _ vidType: String?
    ) async throws -> PaginatedResponse<DownloadResponse>
    public var getDownload: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> DownloadResponse
    public var addDownloads: @Sendable (
        _ config: ServerConfig,
        _ items: [AddDownloadItem],
        _ autostart: Bool,
        _ flat: Bool,
        _ force: Bool
    ) async throws -> Void
    public var updateDownloads: @Sendable (
        _ config: ServerConfig,
        _ videoIds: [String],
        _ status: String
    ) async throws -> Void
    public var deleteDownloads: @Sendable (
        _ config: ServerConfig,
        _ videoIds: [String]
    ) async throws -> Void
    public var updateDownload: @Sendable (
        _ config: ServerConfig,
        _ id: String,
        _ status: String
    ) async throws -> Void
    public var deleteDownload: @Sendable (
        _ config: ServerConfig,
        _ id: String
    ) async throws -> Void
    public var getDownloadAggs: @Sendable (
        _ config: ServerConfig
    ) async throws -> DownloadAggsResponse
}

extension DownloadService: DependencyKey {
    public static let liveValue = DownloadService(
        getDownloads: { config, page, filter, channel, query, vidType in
            var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
            if let filter { queryItems.append(URLQueryItem(name: "filter", value: filter)) }
            if let channel { queryItems.append(URLQueryItem(name: "channel", value: channel)) }
            if let query { queryItems.append(URLQueryItem(name: "q", value: query)) }
            if let vidType { queryItems.append(URLQueryItem(name: "vid_type", value: vidType)) }

            let request = NetworkAPIRequest<PaginatedResponse<DownloadResponse>>(
                config: config,
                path: .downloadList,
                queryItems: queryItems
            )
            return try await request.execute().data
        },
        getDownload: { config, id in
            let request = NetworkAPIRequest<DownloadResponse>(
                config: config,
                path: .download(id: id)
            )
            return try await request.execute().data
        },
        addDownloads: { config, items, autostart, flat, force in
            var queryItems: [URLQueryItem] = []
            if autostart { queryItems.append(URLQueryItem(name: "autostart", value: "true")) }
            if flat { queryItems.append(URLQueryItem(name: "flat", value: "true")) }
            if force { queryItems.append(URLQueryItem(name: "force", value: "true")) }
            let body = try JSONEncoder().encode(AddDownloadRequest(data: items))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .downloadList,
                queryItems: queryItems.isEmpty ? nil : queryItems,
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        updateDownloads: { config, videoIds, status in
            let body = try JSONEncoder().encode(BulkDownloadUpdateRequest(videoIds: videoIds, status: status))
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .downloadList,
                method: .patch,
                body: body
            )
            _ = try await request.execute()
        },
        deleteDownloads: { config, videoIds in
            let body = try JSONEncoder().encode(["video_ids": videoIds])
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .downloadList,
                method: .delete,
                body: body
            )
            _ = try await request.execute()
        },
        updateDownload: { config, id, status in
            let body = try JSONEncoder().encode(["status": status])
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .download(id: id),
                method: .post,
                body: body
            )
            _ = try await request.execute()
        },
        deleteDownload: { config, id in
            let request = NetworkAPIRequest<EmptyResponse>(
                config: config,
                path: .download(id: id),
                method: .delete
            )
            _ = try await request.execute()
        },
        getDownloadAggs: { config in
            let request = NetworkAPIRequest<DownloadAggsResponse>(
                config: config,
                path: .downloadAggs
            )
            return try await request.execute().data
        }
    )

    public static var testValue: DownloadService { DownloadService() }
}
