import Foundation
import UIKit
import VLCKit

/// Swift port of upstream `VLCMetaData` (Obj-C). Mutable bag the
/// `PlaybackService` fills from the current `VLCMedia`'s tags + the
/// app's own knowledge of what's playing (e.g. queue title overrides).
/// Pushed out to the player VC via `displayMetadataForPlaybackService:metadata:`
/// and to MPNowPlayingInfoCenter for lock-screen display.
@objc(VLCMetaData)
public final class VLCMetaData: NSObject {
    @objc public var title: String?
    @objc public var descriptiveTitle: String?
    @objc public var artworkImage: UIImage?
    @objc public var artist: String?
    @objc public var albumName: String?
    @objc public var isAudioOnly: Bool = false
    @objc public var trackNumber: NSNumber?
    @objc public var playbackDuration: NSNumber?
    @objc public var elapsedPlaybackTime: NSNumber?
    @objc public var playbackRate: NSNumber?
    @objc public var position: NSNumber?
    @objc public var identifier: NSNumber?
    @objc public var isLiveStream: Bool = false

    public override init() {
        super.init()
    }

    /// Pull tags off the playing media + sync transport state. Upstream's
    /// version cross-references VLCMLMedia for podcast/library metadata
    /// — we skip that path (no media library) and read straight from
    /// `VLCMedia` tags.
    @objc public func updateMetadata(
        from media: VLCMLMedia?,
        mediaPlayer: VLCMediaPlayer
    ) {
        guard let vlcMedia = mediaPlayer.media else {
            updateExposedTiming(from: mediaPlayer)
            return
        }
        title = vlcMedia.metaData.title ?? title
        artist = vlcMedia.metaData.artist ?? artist
        albumName = vlcMedia.metaData.album ?? albumName
        // Track number, artwork URL, etc. are all on `vlcMedia.metaData`
        // but the player VC only reads title/artist/artwork, so we keep
        // this minimal until something downstream needs more.
        descriptiveTitle = title
        playbackDuration = NSNumber(value: vlcMedia.length.intValue / 1000)
        updateExposedTiming(from: mediaPlayer)
    }

    @objc public func updateExposedTiming(from mediaPlayer: VLCMediaPlayer) {
        elapsedPlaybackTime = NSNumber(value: mediaPlayer.time.intValue / 1000)
        playbackRate = NSNumber(value: mediaPlayer.rate)
        position = NSNumber(value: mediaPlayer.position)
    }
}
