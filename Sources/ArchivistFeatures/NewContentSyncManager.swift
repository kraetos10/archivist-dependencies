import ArchivistNetworking
import Dependencies
import Foundation

public actor NewContentSyncManager {
    private var channelIdsWithNewContent: Set<String> = []
    private static let lastLaunchKey = "newContentSync.lastLaunchDate"

    public init() {}

    /// Fetch the last page of the download queue and check for items
    /// published since the last app launch.
    public func sync(config: ServerConfig) async {
        guard let lastLaunch = UserDefaults.standard.object(forKey: Self.lastLaunchKey) as? Date else {
            // First launch — don't mark anything as new, just record the date
            UserDefaults.standard.set(Date(), forKey: Self.lastLaunchKey)
            return
        }
        let downloadService = DownloadService()

        do {
            // Fetch page 1 to discover lastPage
            let firstPage = try await downloadService.getDownloads(
                config: config,
                page: 1,
                filter: "pending",
                channel: nil,
                query: nil,
                vidType: nil
            )

            let lastPage = firstPage.paginate.lastPage
            let pageToCheck: PaginatedResponse<DownloadResponse>

            if lastPage > 1 {
                pageToCheck = try await downloadService.getDownloads(
                    config: config,
                    page: lastPage,
                    filter: "pending",
                    channel: nil,
                    query: nil,
                    vidType: nil
                )
            } else {
                pageToCheck = firstPage
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]

            var newIds: Set<String> = []
            for download in pageToCheck.data {
                guard let publishedStr = download.published,
                      let publishedDate = formatter.date(from: publishedStr)
                        ?? fallbackFormatter.date(from: publishedStr) else {
                    continue
                }
                if publishedDate > lastLaunch {
                    newIds.insert(download.channelId)
                }
            }

            channelIdsWithNewContent = newIds
        } catch {
            // Silently fail — this is a best-effort feature
        }

        // Update last launch date for next comparison
        UserDefaults.standard.set(Date(), forKey: Self.lastLaunchKey)
    }

    /// Check if a specific channel has new content in the queue.
    public func hasNewContent(channelId: String) -> Bool {
        channelIdsWithNewContent.contains(channelId)
    }

    /// Clear the badge for a channel after the user taps into it.
    public func markSeen(channelId: String) {
        channelIdsWithNewContent.remove(channelId)
    }

    /// All channel IDs that currently have new content.
    public func allNewChannelIds() -> Set<String> {
        channelIdsWithNewContent
    }

    /// The date of the previous app launch, used to determine which videos are "new".
    public func lastLaunchDate() -> Date? {
        UserDefaults.standard.object(forKey: Self.lastLaunchKey) as? Date
    }
}

// MARK: - Dependency Registration

extension NewContentSyncManager: DependencyKey {
    public static let liveValue = NewContentSyncManager()
    public static let testValue = NewContentSyncManager()
}

extension DependencyValues {
    public var newContentSyncManager: NewContentSyncManager {
        get { self[NewContentSyncManager.self] }
        set { self[NewContentSyncManager.self] = newValue }
    }
}
