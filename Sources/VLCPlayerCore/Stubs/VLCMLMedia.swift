import Foundation
import UIKit
import VLCKit

/// Stand-in for upstream `VLCMLMedia` — a row from VLCMediaLibraryKit
/// representing a library entry with watched/podcast/etc. flags. We
/// don't ship a media library, so this is a thin wrapper around a
/// `VLCMedia` URL with no-op flags. The player VC reaches for
/// `VLCMLMedia(forPlaying:)` to resolve library state for the current
/// media; here it always returns nil-equivalent (zero progress, not
/// watched, no chapters, no bookmarks).
@objc(VLCMLMedia)
public final class VLCMLMedia: NSObject {
    @objc public let url: URL?
    @objc public let title: String

    @objc public var progress: Float = 0
    @objc public var isWatched: Bool = false
    @objc public var isPodcast: Bool = false
    @objc public var bookmarks: [Any] = []
    @objc public var chapters: [Any] = []

    /// Library media type — used by upstream to bail to the audio
    /// player when a video has no tracks. We always classify as
    /// video so the video player owns playback.
    public enum MediaType { case audio, video, unknown }
    public func type() -> MediaType { .video }

    @objc public init?(forPlaying media: VLCMedia?) {
        guard let media else { return nil }
        self.url = media.url
        self.title = media.metaData.title ?? media.url?.lastPathComponent ?? ""
        super.init()
    }

    @objc public init(url: URL, title: String) {
        self.url = url
        self.title = title
        super.init()
    }
}
