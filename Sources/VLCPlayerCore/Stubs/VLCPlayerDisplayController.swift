import Foundation
import UIKit

/// Stand-in for upstream `VLCPlayerDisplayController`, the singleton
/// that owns the on-screen presentation of the player VC (full / mini)
/// and brokers between PlaybackService and the visible UIViewController.
/// We don't use that presentation pipeline — our SwiftUI wrapper hosts
/// `VideoPlayerViewController` directly — so this is a no-op shell that
/// only exists to satisfy `PlaybackService.playerDisplayController`
/// references in the lifted code.
@objc(VLCPlayerDisplayController)
public final class VLCPlayerDisplayController: NSObject {
    @objc public weak var miniPlayer: NSObject?
    @objc public var displayMode: Int = 0

    @objc public func showFullscreenPlayback() {}
    @objc public func closeFullscreenPlayback() {}
    @objc public func dismissPlaybackView() {}
    @objc public func updatePlayerDisplayBasedOn(playbackService _: NSObject) {}
}

/// Aspect-ratio enum upstream defines in VLCPlaybackController-iOS bridge.
/// Names + ordering preserved so call sites switch verbatim.
@objc public enum VLCAspectRatio: Int {
    case `default` = 0
    case fillToScreen
    case fourToThree
    case sixteenToTen
    case sixteenToNine
}

let VLCAspectRatioDefault = VLCAspectRatio.default.rawValue
