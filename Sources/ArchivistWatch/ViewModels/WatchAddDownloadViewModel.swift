#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchAddDownloadViewModel {
    public var urlText = ""
    public var isAdding = false
    public var errorMessage: String?
    public var didAdd = false

    private let config: ServerConfig
    private let downloadService: any DownloadServiceType

    public init(
        config: ServerConfig,
        downloadService: any DownloadServiceType = DownloadService()
    ) {
        self.config = config
        self.downloadService = downloadService
    }

    public func addToQueue() async {
        let videoId = extractVideoId(from: urlText)
            ?? urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !videoId.isEmpty else { return }

        isAdding = true
        errorMessage = nil

        do {
            try await downloadService.addDownloads(
                config: config,
                items: [AddDownloadItem(youtubeId: videoId, status: "pending")],
                autostart: true,
                flat: false,
                force: false
            )
            didAdd = true
        } catch {
            errorMessage = String(localized: "queue.addFailed", bundle: Bundle.module)
        }
        isAdding = false
    }

    private func extractVideoId(from input: String) -> String? {
        if let range = input.range(of: "v=([a-zA-Z0-9_-]+)", options: .regularExpression) {
            let match = input[range]
            return String(match.dropFirst(2))
        }
        if let range = input.range(of: "youtu\\.be/([a-zA-Z0-9_-]+)", options: .regularExpression) {
            let match = input[range]
            if let slashIndex = match.lastIndex(of: "/") {
                return String(match[match.index(after: slashIndex)...])
            }
        }
        if let range = input.range(of: "/shorts/([a-zA-Z0-9_-]+)", options: .regularExpression) {
            let match = input[range]
            let components = match.split(separator: "/")
            if let last = components.last {
                return String(last)
            }
        }
        return nil
    }
}
#endif
