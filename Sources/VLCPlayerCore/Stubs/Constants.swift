// VLC for iOS UserDefaults keys + enums lifted from VLCConstants.h /
// kVLCSettingDefaults.swift in the original project. Values match the
// upstream strings so SettingsBundle.plist drops still work, but our
// adoption of the player VC doesn't need or write any of these — they
// exist purely to satisfy `UserDefaults.standard.bool(forKey:)` lookups
// scattered through PlayerController.

import Foundation
import VLCKit

// MARK: - Gesture toggles

public let kVLCSettingVolumeGesture            = "EnableVolumeGesture"
public let kVLCSettingPlayPauseGesture         = "EnablePlayPauseGesture"
public let kVLCSettingBrightnessGesture        = "EnableBrightnessGesture"
public let kVLCSettingSeekGesture              = "EnableSeekGesture"
public let kVLCSettingCloseGesture             = "EnableCloseGesture"
public let kVLCSettingPlaybackLongTouchSpeedUp = "EnableLongTouchSpeedUp"
public let kVLCSettingPlaybackForwardSkipLength  = "PlaybackForwardSkipLength"
public let kVLCSettingPlaybackBackwardSkipLength = "PlaybackBackwardSkipLength"
public let kVLCSettingPlaybackSpeedDefaultValue  = "PlaybackSpeedDefaultValue"
public let kVLCShowRemainingTime                  = "ShowRemainingTime"
public let kVLCSettingPlayerControlDuration       = "PlayerControlDuration"
public let kVLCSettingRotationLock                = "RotationLock"
public let kVLCSubtitlesCacheFolderName           = "subs-cache"
public let kVLCSettingPauseWhenShowingControls    = "PauseWhenShowingControls"
public let kVLCSettingSnapshotGesture             = "SnapshotGesture"
public let kVLCSettingPlaybackTapSwipeEqual       = "PlaybackTapSwipeEqual"
public let kVLCSettingPlaybackForwardBackwardEqual = "PlaybackForwardBackwardEqual"
public let kVLCSettingPlaybackForwardSkipLengthSwipe  = "PlaybackForwardSkipLengthSwipe"
public let kVLCSettingPlaybackBackwardSkipLengthSwipe = "PlaybackBackwardSkipLengthSwipe"
public let kVLCCustomProfileEnabled               = "CustomEqualizerProfileEnabled"
public let kVLCSettingEqualizerProfile            = "EqualizerProfile"
public let kVLCCustomEqualizerProfiles            = "CustomEqualizerProfiles"
public let KVLCPlayerBrightness                   = kVLCPlayerBrightness  // upstream typo fix

// MARK: - Player state

public let kVLCPlayerIsShuffleEnabled          = "PlayerIsShuffleEnabled"
public let kVLCPlayerIsRepeatEnabled           = "PlayerIsRepeatEnabled"
public let kVLCPlayerShouldRememberState       = "PlayerShouldRememberState"
public let kVLCPlayerShouldRememberBrightness  = "PlayerShouldRememberBrightness"
public let kVLCPlayerShowPlaybackSpeedShortcut = "PlayerShowPlaybackSpeedShortcut"
public let kVLCPlayerBrightness                = "PlayerBrightness"

// MARK: - Theming

public let kVLCSettingAppTheme                 = "AppTheme"
public let kVLCSettingAppThemeBlack            = "AppThemeBlack"

/// Stub of upstream UIKit appearance customisation. We don't push our
/// theme through `UIAppearance` proxies — the player VC owns its colours
/// directly.
@objc public final class AppearanceManager: NSObject {
    @objc public static func setupAppearance(theme _: NSObject?) {}
}

// MARK: - Repeat mode is provided by VLCKit's `VLCRepeatMode` enum.
