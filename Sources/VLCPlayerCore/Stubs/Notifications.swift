import Foundation

// VLC's external-display companion ("non-interactive scene") fires these
// when the user attaches/removes a secondary screen. We don't ship that
// scene, so the names exist as observable symbols only — they're never
// posted, and any registered observer is dead code in our context.
//
// Upstream typed these as raw strings (Obj-C-era), and the player code
// wraps them in `NSNotification.Name(rawValue:)` at the call site, so
// keep them as `String` to match those construction sites verbatim.

public let VLCNonInteractiveWindowSceneBecameActive  = "VLCNonInteractiveWindowSceneBecameActive"
public let VLCNonInteractiveWindowSceneDisconnected  = "VLCNonInteractiveWindowSceneDisconnected"

public let VLCDidAppendMediaToQueue                  = "VLCDidAppendMediaToQueue"
public let VLCDidRemoveMediaFromQueue                = "VLCDidRemoveMediaFromQueue"
public let VLCPlaybackServicePlaybackDidStop         = "VLCPlaybackServicePlaybackDidStop"
