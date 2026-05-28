#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import CarPlay
import UIKit

@MainActor
public final class CarPlayCoordinator {
    private var interfaceController: CPInterfaceController?
    private let dataProvider: CarPlayDataProvider
    private let videoService = VideoService.liveValue
    private var currentSort: VideoSortOrder = .published
    private weak var recentTemplate: CPListTemplate?

    public init(dataProvider: CarPlayDataProvider) {
        self.dataProvider = dataProvider
    }

    public func setup(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        let recentTemplate = CPListTemplate(
            title: String(localized: "Recent Videos"),
            sections: []
        )
        recentTemplate.tabImage = UIImage(systemName: "play.rectangle.fill")

        let channelsTemplate = CPListTemplate(
            title: String(localized: "Channels"),
            sections: []
        )
        channelsTemplate.tabImage = UIImage(systemName: "person.crop.rectangle.stack.fill")

        let playlistsTemplate = CPListTemplate(
            title: String(localized: "Playlists"),
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
        // Save watch progress before stopping playback
        let position = Int(PlayerManager.shared.currentTime)
        let videoId = PlayerManager.shared.currentVideoID
        let config = dataProvider.serverConfig
        if let videoId, position > 0 {
            Task.detached { [videoService = self.videoService] in
                try? await videoService.setProgress(
                    config: config,
                    videoId: videoId,
                    position: position
                )
            }
        }
        PlayerManager.shared.stop()
        interfaceController = nil
    }

    // MARK: - Data Loading

    private func loadRecentVideos(into template: CPListTemplate) {
        Task {
            do {
                let videos = try await dataProvider.fetchRecentVideos(sort: currentSort)
                let videoItems = videos.map { video in
                    makeVideoListItem(video)
                }

                let sortItems = VideoSortOrder.allCases.map { sort in
                    let label = sort == currentSort ? "✓ \(sort.label)" : sort.label
                    let item = CPListItem(
                        text: label,
                        detailText: nil
                    )
                    item.handler = { [weak self] _, completion in
                        guard let self else { completion(); return }
                        self.currentSort = sort
                        if let template = self.recentTemplate {
                            self.loadRecentVideos(into: template)
                        }
                        completion()
                    }
                    return item
                }
                let sortSection = CPListSection(
                    items: sortItems,
                    header: String(localized: "Sort By"),
                    sectionIndexTitle: nil
                )
                let videoSection = CPListSection(items: videoItems)

                template.updateSections([sortSection, videoSection])
            } catch {
                showError(in: template, message: String(localized: "Failed to load videos")) { [weak self] in
                    self?.loadRecentVideos(into: template)
                }
            }
        }
    }

    private func loadChannels(into template: CPListTemplate) {
        Task {
            do {
                let channels = try await dataProvider.fetchChannels()
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
            } catch {
                showError(in: template, message: String(localized: "Failed to load channels")) { [weak self] in
                    self?.loadChannels(into: template)
                }
            }
        }
    }

    private func loadPlaylists(into template: CPListTemplate) {
        Task {
            do {
                let playlists = try await dataProvider.fetchPlaylists()
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
            } catch {
                showError(in: template, message: String(localized: "Failed to load playlists")) { [weak self] in
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
        Task {
            do {
                let videos = try await dataProvider.fetchChannelVideos(channelId: channel.channelId)
                let items = videos.map { makeVideoListItem($0) }
                template.updateSections([CPListSection(items: items)])
            } catch {
                showError(in: template, message: String(localized: "Failed to load videos")) { [weak self] in
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
        Task {
            do {
                let videos = try await dataProvider.fetchPlaylistVideos(playlistId: playlist.playlistId)
                let items = videos.map { makeVideoListItem($0) }
                template.updateSections([CPListSection(items: items)])
            } catch {
                showError(in: template, message: String(localized: "Failed to load videos")) { [weak self] in
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

        PlayerManager.shared.load(
            url: url,
            startPosition: video.resumePositionSeconds,
            videoId: videoId,
            expectedSize: video.mediaSize.map { Int64($0) }
        )
        PlayerManager.shared.currentVideoID = videoId
        PlayerManager.shared.currentMetadata = PlayerManager.NowPlayingMetadata(
            title: video.title,
            artist: video.channelName,
            duration: Double(video.player?.duration ?? 0),
            artworkURL: dataProvider.buildThumbnailURL(for: video.vidThumbUrl),
            authHeaders: config.authHeaders
        )

        PlayerManager.shared.onPause = { [videoService = self.videoService] in
            let position = Int(PlayerManager.shared.currentTime)
            guard position > 0 else { return }
            Task.detached {
                try? await videoService.setProgress(config: config, videoId: videoId, position: position)
            }
        }
        PlayerManager.shared.onPlaybackCompleted = { [videoService = self.videoService] in
            Task.detached {
                try? await videoService.setWatched(
                    config: config,
                    videoId: videoId,
                    isWatched: true
                )
            }
        }

        Task { [videoService = self.videoService] in
            for await _ in PlayerManager.shared.playbackEndEvents() {
                let position = Int(PlayerManager.shared.currentTime)
                guard position > 0 else { continue }
                try? await videoService.setProgress(
                    config: config,
                    videoId: videoId,
                    position: position
                )
            }
        }

        CPNowPlayingTemplate.shared.updateNowPlayingButtons([])
        interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in }
    }

    // MARK: - Helpers

    private func makeVideoListItem(_ video: VideoResponse) -> CPListItem {
        let item = CPListItem(
            text: video.title,
            detailText: "\(video.channelName) · \(video.durationStr ?? "")"
        )
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
        Task.detached {
            var request = URLRequest(url: url)
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let image = UIImage(data: data) else { return }
            let size = CGSize(width: 44, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)
            let resized = renderer.image { _ in
                let scale = max(size.width / image.size.width, size.height / image.size.height)
                let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
                image.draw(in: CGRect(origin: origin, size: drawSize))
            }
            await MainActor.run {
                item.setImage(resized)
            }
        }
    }

    private func showError(
        in template: CPListTemplate,
        message: String,
        retry: (() -> Void)? = nil
    ) {
        let item = CPListItem(
            text: message,
            detailText: retry != nil ? String(localized: "Tap to retry") : nil
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
