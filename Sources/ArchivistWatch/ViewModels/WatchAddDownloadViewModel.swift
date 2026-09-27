#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchAddDownloadViewModel: Identifiable {
    /// Bound to the text field.
    public var urlText = ""
    public private(set) var isAdding = false
    public private(set) var errorMessage: String?
    public private(set) var didAdd = false

    @ObservationIgnored private let config: ServerConfig
    @ObservationIgnored private let service: DownloadService

    public init(
        config: ServerConfig,
        service: DownloadService = .liveValue
    ) {
        self.config = config
        self.service = service
    }

    public var isAddDisabled: Bool {
        videoId == nil || isAdding
    }

    public func addButtonTapped() async {
        guard let videoId, !isAdding else { return }
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }

        do {
            try await service.addDownloads(
                config: config,
                items: [AddDownloadItem(youtubeId: videoId, status: DownloadStatus.pending.rawValue)],
                autostart: true,
                flat: false,
                force: false
            )
            didAdd = true
        } catch {
            errorMessage = String(localized: "queue.addFailed", bundle: .module)
        }
    }

    private var videoId: String? {
        Self.videoId(from: urlText)
    }

    /// The video id from a YouTube watch, share or Shorts link, or the text
    /// itself when it is already a bare id.
    static func videoId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let patterns = [
            /[?&]v=([A-Za-z0-9_-]+)/,
            /youtu\.be\/([A-Za-z0-9_-]+)/,
            /\/shorts\/([A-Za-z0-9_-]+)/,
            /\/live\/([A-Za-z0-9_-]+)/
        ]
        for pattern in patterns {
            if let match = trimmed.firstMatch(of: pattern) {
                return String(match.1)
            }
        }
        return trimmed.wholeMatch(of: /[A-Za-z0-9_-]+/) != nil ? trimmed : nil
    }
}

extension WatchAddDownloadViewModel: Hashable {
    nonisolated public static func == (
        lhs: WatchAddDownloadViewModel,
        rhs: WatchAddDownloadViewModel
    ) -> Bool {
        lhs === rhs
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
#endif
