#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import CarPlay
import Dependencies
import UIKit

@MainActor
public final class CarPlayCoordinator {
    private var interfaceController: CPInterfaceController?
    private let dataProvider: CarPlayDataProvider
    @Dependency(\.playerClient) private var playerClient
    @Dependency(\.videoService) private var videoService
    private var currentSort: VideoSortOrder = .published
    private weak var recentTemplate: CPListTemplate?
    /// Subscription to player events for the video CarPlay is currently
    /// playing. Held so starting another video — or tearing the scene
    /// down — replaces it rather than leaking a second listener that would
    /// double-save progress.
    private var playbackObservationTask: Task<Void, Never>?
    /// List loads and thumbnail fetches in flight, cancelled with the scene.
    private var loadTasks: [Task<Void, Never>] = []

    /// CarPlay's own cap on list rows.
    private var listLimit: Int {
        CPListTemplate.maximumItemCount
    }

    public init(dataProvider: CarPlayDataProvider) {
        self.dataProvider = dataProvider
    }

    public func setup(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        let recentTemplate = CPListTemplate(
            title: String.localised("carPlay.recentVideos", table: .generic),
            sections: []
        )
        recentTemplate.tabImage = UIImage(systemName: "play.rectangle.fill")

        let channelsTemplate = CPListTemplate(
            title: String.localised("generic.channels", table: .generic),
            sections: []
        )
        channelsTemplate.tabImage = UIImage(systemName: "person.crop.rectangle.stack.fill")

        let playlistsTemplate = CPListTemplate(
            title: String.localised("generic.playlists", table: .generic),
            sections: []
        )
        playlistsTemplate.tabImage = UIImage(systemName: "list.bullet.rectangle.fill")

        self.recentTemplate = recentTemplate

        let tabBar = CPTabBarTemplate(templates: [recentTemplate, channelsTemplate, playlistsTemplate])
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        loadRecentVideos(into: recentTemplate)
        loadChannels(into: channelsTemplate)
        loadPlaylists(into: playlistsTemplate)
    }

    public func teardown() {
        // Read the position and stop in one turn — `stop()` zeroes it.
        let videoId = playerClient.currentVideoID()
        let position = Int(playerClient.stopReturningPosition())
        let config = dataProvider.serverConfig
        if let videoId, position > 0 {
            // Detached: the save has to outlive the scene.
            Task.detached { [videoService] in
                try? await videoService.setProgress(
                    config: config,
                    videoId: videoId,
                    position: position
                )
            }
        }
        // Drop the event subscription with the scene. Left running it would
        // keep saving progress for a CarPlay session the user has already
        // disconnected from.
        playbackObservationTask?.cancel()
        playbackObservationTask = nil
        for task in loadTasks {
            task.cancel()
        }
        loadTasks = []
        interfaceController = nil
    }

    // MARK: - Data Loading

    /// Runs `operation`, keeping hold of it so teardown can cancel it.
    private func track(_ operation: @escaping @MainActor () async -> Void) {
        loadTasks.removeAll(where: \.isCancelled)
        loadTasks.append(Task { await operation() })
    }

    private func loadRecentVideos(into template: CPListTemplate) {
        let sort = currentSort
        let limit = listLimit
        track { [weak self] in
            guard let self else { return }
            do {
                let videos = try await dataProvider.fetchRecentVideos(sort: sort, limit: limit)
                guard !Task.isCancelled else { return }
                let sortSection = CPListSection(
                    items: VideoSortOrder.allCases.map { makeSortItem($0) },
                    header: String.localised("carPlay.sortBy", table: .generic),
                    sectionIndexTitle: nil
                )
                let videoSection = CPListSection(items: videos.map { makeVideoListItem($0) })
                template.updateSections([sortSection, videoSection])
            } catch is CancellationError {
                return
            } catch {
                showError(in: template, message: String.localised("carPlay.loadVideosFailed", table: .generic)) { [weak self] in
                    self?.loadRecentVideos(into: template)
                }
            }
        }
    }

    private func loadChannels(into template: CPListTemplate) {
        let limit = listLimit
        track { [weak self] in
            guard let self else { return }
            do {
                let channels = try await dataProvider.fetchChannels(limit: limit)
                guard !Task.isCancelled else { return }
                let items = channels.map { channel in
                    let item = CPListItem(
                        text: channel.channelName,
                        detailText: channel.formattedSubs
                    )
                    item.accessoryType = .disclosureIndicator
                    item.handler = { [weak self] _, completion in
                        self?.showChannelVideos(channel)
                        completion()
                    }
                    loadThumbnail(for: item, path: channel.channelThumbUrl)
                    return item
                }
                template.updateSections([CPListSection(items: items)])
            } catch is CancellationError {
                return
            } catch {
                showError(in: template, message: String.localised("carPlay.loadChannelsFailed", table: .generic)) { [weak self] in
                    self?.loadChannels(into: template)
                }
            }
        }
    }

    private func loadPlaylists(into template: CPListTemplate) {
        let limit = listLimit
        track { [weak self] in
            guard let self else { return }
            do {
                let playlists = try await dataProvider.fetchPlaylists(limit: limit)
                guard !Task.isCancelled else { return }
                let items = playlists.map { playlist in
                    let item = CPListItem(
                        text: playlist.playlistName,
                        detailText: playlist.playlistChannel
                    )
                    item.accessoryType = .disclosureIndicator
                    item.handler = { [weak self] _, completion in
                        self?.showPlaylistVideos(playlist)
                        completion()
                    }
                    loadThumbnail(for: item, path: playlist.playlistThumbnail)
                    return item
                }
                template.updateSections([CPListSection(items: items)])
            } catch is CancellationError {
                return
            } catch {
                showError(in: template, message: String.localised("carPlay.loadPlaylistsFailed", table: .generic)) { [weak self] in
                    self?.loadPlaylists(into: template)
                }
            }
        }
    }

    // MARK: - Drill-Down

    private func showChannelVideos(_ channel: ChannelResponse) {
        let template = CPListTemplate(title: channel.channelName, sections: [])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
        loadChannelVideos(channel, into: template)
    }

    private func loadChannelVideos(
        _ channel: ChannelResponse,
        into template: CPListTemplate
    ) {
        let limit = listLimit
        track { [weak self] in
            guard let self else { return }
            do {
                let videos = try await dataProvider.fetchChannelVideos(channelId: channel.channelId, limit: limit)
                guard !Task.isCancelled else { return }
                template.updateSections([CPListSection(items: videos.map { makeVideoListItem($0) })])
            } catch is CancellationError {
                return
            } catch {
                showError(in: template, message: String.localised("carPlay.loadVideosFailed", table: .generic)) { [weak self] in
                    self?.loadChannelVideos(channel, into: template)
                }
            }
        }
    }

    private func showPlaylistVideos(_ playlist: PlaylistResponse) {
        let template = CPListTemplate(title: playlist.playlistName, sections: [])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
        loadPlaylistVideos(playlist, into: template)
    }

    private func loadPlaylistVideos(
        _ playlist: PlaylistResponse,
        into template: CPListTemplate
    ) {
        let limit = listLimit
        track { [weak self] in
            guard let self else { return }
            do {
                let videos = try await dataProvider.fetchPlaylistVideos(playlistId: playlist.playlistId, limit: limit)
                guard !Task.isCancelled else { return }
                template.updateSections([CPListSection(items: videos.map { makeVideoListItem($0) })])
            } catch is CancellationError {
                return
            } catch {
                showError(in: template, message: String.localised("carPlay.loadVideosFailed", table: .generic)) { [weak self] in
                    self?.loadPlaylistVideos(playlist, into: template)
                }
            }
        }
    }

    // MARK: - Playback

    private func playVideo(_ video: VideoResponse) {
        guard let url = dataProvider.buildMediaURL(for: video) else { return }
        let config = dataProvider.serverConfig
        let videoId = video.videoId

        // One subscription covers progress saves and the watched flag,
        // taken before the load so nothing it emits is missed. A broadcast
        // stream lets CarPlay and the VideoDetail feature observe at once.
        let events = playerClient.startPlayback(PlayerClient.PlaybackRequest(
            url: url,
            startPosition: video.resumePositionSeconds,
            videoId: videoId,
            expectedSize: video.mediaSize.map { Int64($0) },
            metadata: PlayerManager.NowPlayingMetadata(
                title: video.title,
                artist: video.channelName,
                duration: Double(video.player?.duration ?? 0),
                artworkURL: dataProvider.buildThumbnailURL(for: video.vidThumbUrl),
                authHeaders: config.authHeaders
            )
        ))

        playbackObservationTask?.cancel()
        playbackObservationTask = Task { [videoService] in
            for await event in events {
                switch event {
                case .paused(let eventVideoId, let position):
                    guard eventVideoId == videoId, position > 0 else { continue }
                    try? await videoService.setProgress(
                        config: config,
                        videoId: videoId,
                        position: position
                    )

                case .playbackCompleted(let eventVideoId):
                    guard eventVideoId == videoId else { continue }
                    try? await videoService.setWatched(
                        config: config,
                        videoId: videoId,
                        isWatched: true
                    )

                default:
                    continue
                }
            }
        }

        CPNowPlayingTemplate.shared.updateNowPlayingButtons([])
        interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in }
    }

    // MARK: - Helpers

    private func makeSortItem(_ sort: VideoSortOrder) -> CPListItem {
        let label = sort == currentSort ? "✓ \(sort.label)" : sort.label
        let item = CPListItem(text: label, detailText: nil)
        item.handler = { [weak self] _, completion in
            guard let self else { completion(); return }
            currentSort = sort
            if let template = recentTemplate {
                loadRecentVideos(into: template)
            }
            completion()
        }
        return item
    }

    private func makeVideoListItem(_ video: VideoResponse) -> CPListItem {
        let detail = [video.channelName, video.durationStr]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let item = CPListItem(text: video.title, detailText: detail)
        item.isExplicitContent = false
        item.handler = { [weak self] _, completion in
            self?.playVideo(video)
            completion()
        }
        loadThumbnail(for: item, path: video.vidThumbUrl)
        return item
    }

    private func loadThumbnail(
        for item: CPListItem,
        path: String?
    ) {
        guard let url = dataProvider.buildThumbnailURL(for: path) else { return }
        let headers = dataProvider.serverConfig.authHeaders
        track {
            guard let image = await Self.fetchThumbnail(url: url, headers: headers) else { return }
            item.setImage(image)
        }
    }

    /// Downloads and scales a list thumbnail off the main actor.
    nonisolated private static func fetchThumbnail(
        url: URL,
        headers: [String: String]
    ) async -> UIImage? {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return nil }
        let size = CGSize(width: 44, height: 44)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    private func showError(
        in template: CPListTemplate,
        message: String,
        retry: (() -> Void)? = nil
    ) {
        let item = CPListItem(
            text: message,
            detailText: retry != nil ? String.localised("generic.tapToRetry", table: .generic) : nil
        )
        if let retry {
            item.handler = { _, completion in
                retry()
                completion()
            }
        }
        template.updateSections([CPListSection(items: [item])])
    }
}
#endif
