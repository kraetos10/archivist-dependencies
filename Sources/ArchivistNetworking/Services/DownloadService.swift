import Foundation

public nonisolated protocol DownloadServiceType: Sendable {
    func getDownloads(
        config: ServerConfig,
        page: Int,
        filter: String?,
        channel: String?,
        query: String?,
        vidType: String?
    ) async throws -> PaginatedResponse<DownloadResponse>
    func getDownload(
        config: ServerConfig,
        id: String
    ) async throws -> DownloadResponse
    func addDownloads(
        config: ServerConfig,
        items: [AddDownloadItem],
        autostart: Bool,
        flat: Bool,
        force: Bool
    ) async throws
    func updateDownloads(
        config: ServerConfig,
        videoIds: [String],
        status: String
    ) async throws
    func deleteDownloads(
        config: ServerConfig,
        videoIds: [String]
    ) async throws
    func updateDownload(
        config: ServerConfig,
        id: String,
        status: String
    ) async throws
    func deleteDownload(
        config: ServerConfig,
        id: String
    ) async throws
    func getDownloadAggs(config: ServerConfig) async throws -> DownloadAggsResponse
}

public nonisolated struct DownloadService: DownloadServiceType {
    public init() {}

    public func getDownloads(
        config: ServerConfig,
        page: Int = 1,
        filter: String? = nil,
        channel: String? = nil,
        query: String? = nil,
        vidType: String? = nil
    ) async throws -> PaginatedResponse<DownloadResponse> {
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
    }

    public func getDownload(
        config: ServerConfig,
        id: String
    ) async throws -> DownloadResponse {
        let request = NetworkAPIRequest<DownloadResponse>(
            config: config,
            path: .download(id: id)
        )
        return try await request.execute().data
    }

    public func addDownloads(
        config: ServerConfig,
        items: [AddDownloadItem],
        autostart: Bool,
        flat: Bool,
        force: Bool
    ) async throws {
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
    }

    public func updateDownloads(
        config: ServerConfig,
        videoIds: [String],
        status: String
    ) async throws {
        let body = try JSONEncoder().encode(BulkDownloadUpdateRequest(videoIds: videoIds, status: status))
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .downloadList,
            method: .patch,
            body: body
        )
        _ = try await request.execute()
    }

    public func deleteDownloads(
        config: ServerConfig,
        videoIds: [String]
    ) async throws {
        let body = try JSONEncoder().encode(["video_ids": videoIds])
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .downloadList,
            method: .delete,
            body: body
        )
        _ = try await request.execute()
    }

    public func updateDownload(
        config: ServerConfig,
        id: String,
        status: String
    ) async throws {
        let body = try JSONEncoder().encode(["status": status])
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .download(id: id),
            method: .post,
            body: body
        )
        _ = try await request.execute()
    }

    public func deleteDownload(
        config: ServerConfig,
        id: String
    ) async throws {
        let request = NetworkAPIRequest<EmptyResponse>(
            config: config,
            path: .download(id: id),
            method: .delete
        )
        _ = try await request.execute()
    }

    public func getDownloadAggs(config: ServerConfig) async throws -> DownloadAggsResponse {
        let request = NetworkAPIRequest<DownloadAggsResponse>(
            config: config,
            path: .downloadAggs
        )
        return try await request.execute().data
    }
}
