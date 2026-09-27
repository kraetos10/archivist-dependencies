#if !os(tvOS)
import Foundation
import MediaPlayer
import os
import UIKit

public final class NowPlayingService: Sendable {
    private let commandsConfigured = OSAllocatedUnfairLock(initialState: false)
    /// The in-flight artwork download. Replaced (and the old one cancelled)
    /// on every `configure`, cancelled on `teardown`, so a slow download for
    /// the previous video can't stamp its artwork onto the next one.
    private let artworkTask = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    public init() {}

    // MARK: - Metadata

    public func configure(
        title: String,
        artist: String,
        duration: Double,
        currentTime: Double,
        isPlaying: Bool,
        artworkURL: URL?,
        authHeaders: [String: String]
    ) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(PlaybackSpeed.saved) : 0.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let newTask: Task<Void, Never>? = artworkURL.map { artworkURL in
            Task {
                var request = URLRequest(url: artworkURL)
                for (key, value) in authHeaders {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                // Artwork is decoration: a failed fetch just leaves the
                // lock screen without a picture.
                guard let (data, _) = try? await URLSession.shared.data(for: request),
                      !Task.isCancelled,
                      let image = UIImage(data: data) else { return }
                let size = image.size
                let artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
                // Belt and braces alongside the cancellation: only decorate
                // the entry this download was started for.
                guard var current = MPNowPlayingInfoCenter.default().nowPlayingInfo,
                      current[MPMediaItemPropertyTitle] as? String == title,
                      current[MPMediaItemPropertyArtist] as? String == artist else { return }
                current[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = current
            }
        }
        let previous = artworkTask.withLock { task in
            let old = task
            task = newTask
            return old
        }
        previous?.cancel()
    }

    // MARK: - Playback State

    public func updatePlaybackState(
        isPlaying: Bool,
        currentTime: Double,
        duration: Double
    ) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        // The lock screen extrapolates elapsed time at this rate between
        // updates, so it has to be the real speed, not 1.
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(PlaybackSpeed.saved) : 0.0
        info[MPMediaItemPropertyPlaybackDuration] = duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Remote Commands

    public func setupRemoteCommands() {
        let alreadyConfigured = commandsConfigured.withLock { configured in
            if configured { return true }
            configured = true
            return false
        }
        guard !alreadyConfigured else { return }

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            Task { @MainActor in PlayerManager.shared.resume() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            Task { @MainActor in PlayerManager.shared.pause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in PlayerManager.shared.togglePlayPause() }
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let interval = event.interval
            Task { @MainActor in PlayerManager.shared.skipForward(interval) }
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let interval = event.interval
            Task { @MainActor in PlayerManager.shared.skipBackward(interval) }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in PlayerManager.shared.seekTo(position) }
            return .success
        }
    }

    // MARK: - Teardown

    public func teardown() {
        artworkTask.withLock { task in
            task?.cancel()
            task = nil
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        let wasConfigured = commandsConfigured.withLock { configured in
            let was = configured
            configured = false
            return was
        }
        if wasConfigured {
            let center = MPRemoteCommandCenter.shared()
            center.playCommand.removeTarget(nil)
            center.pauseCommand.removeTarget(nil)
            center.togglePlayPauseCommand.removeTarget(nil)
            center.skipForwardCommand.removeTarget(nil)
            center.skipBackwardCommand.removeTarget(nil)
            center.changePlaybackPositionCommand.removeTarget(nil)
        }
    }
}
#endif
