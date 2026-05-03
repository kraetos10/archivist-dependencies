// Swift port of upstream VLCPlaybackService.m (Obj-C, ~2200 LOC).
// Preserves the public API surface the lifted player VCs bind to,
// drops the parts our adoption doesn't need (VLCDialogProvider,
// EqualizerView delegate, external-screen pipeline, +MediaLibrary
// extension that persisted state into VLCMediaLibraryKit). The queue
// layer is preserved verbatim against `VLCMediaListPlayer` so VLC's
// next/previous/repeat/shuffle behaviour is unchanged.

#if os(iOS) || os(tvOS)
import AVFoundation
import Foundation
import MediaPlayer
import UIKit
import VLCKit

// MARK: - Notification names

public let VLCPlaybackServicePlaybackDidStart            = "VLCPlaybackServicePlaybackDidStart"
public let VLCPlaybackServicePlaybackDidPause            = "VLCPlaybackServicePlaybackDidPause"
public let VLCPlaybackServicePlaybackDidResume           = "VLCPlaybackServicePlaybackDidResume"
public let VLCPlaybackServicePlaybackWillStop            = "VLCPlaybackServicePlaybackWillStop"
public let VLCPlaybackServicePlaybackDidFail             = "VLCPlaybackServicePlaybackDidFail"
public let VLCPlaybackServicePlaybackMetadataDidChange   = "VLCPlaybackServicePlaybackMetadataDidChange"
public let VLCPlaybackServicePlaybackPositionUpdated     = "VLCPlaybackServicePlaybackPositionUpdated"
public let VLCPlaybackServicePlaybackModeUpdated         = "VLCPlaybackServicePlaybackModeUpdated"
public let VLCPlaybackServiceShuffleModeUpdated          = "VLCPlaybackServiceShuffleModeUpdated"
public let VLCPlaybackServicePlaybackDidMoveOnToNextItem = "VLCPlaybackServicePlaybackDidMoveOnToNextItem"
public let VLCLastPlaylistPlayedMedia                    = "LastPlaylistPlayedMedia"
public let kVLCPlayerOpenInMiniPlayer                    = "VLCPlayerOpenInMiniPlayer"

// MARK: - Delegate

@objc public protocol VLCPlaybackServiceDelegate: AnyObject {
    @objc optional func playbackPositionUpdated(_ playbackService: PlaybackService)

    @objc optional func mediaPlayerStateChanged(
        _ currentState: VLCMediaPlayerState,
        isPlaying: Bool,
        currentMediaHasTrackToChooseFrom: Bool,
        currentMediaHasChapters: Bool,
        for playbackService: PlaybackService
    )

    @objc optional func prepare(forMediaPlayback playbackService: PlaybackService)
    @objc optional func showStatusMessage(_ statusMessage: String)
    @objc optional func displayMetadata(for playbackService: PlaybackService, metadata: VLCMetaData)
    @objc optional func playbackServiceDidSwitchAspectRatio(_ aspectRatio: Int)
    @objc optional func playbackService(_ playbackService: PlaybackService, nextMedia: VLCMedia)
    @objc optional func playModeUpdated()
    @objc optional func reloadPlayQueue()
    @objc(pictureInPictureStateDidChangeWithEnabled:)
    optional func pictureInPictureStateDidChange(enabled: Bool)
    @objc optional func updateWidgetsIfNeeded()
}

// MARK: - PlaybackService

@objc(VLCPlaybackService)
public final class PlaybackService: NSObject, @unchecked Sendable {

    // MARK: Public properties (mirrors VLCPlaybackService.h)

    @objc public var videoOutputView: UIView? {
        get { _videoOutputViewWrapper }
        set { setVideoOutputView(newValue) }
    }

    @objc public var mediaList: VLCMediaList = VLCMediaList()
    @objc public var shuffledList: VLCMediaList?

    @objc public weak var delegate: VLCPlaybackServiceDelegate?

    @objc public private(set) var mediaPlayerState: VLCMediaPlayerState = .stopped
    @objc public private(set) var metadata: VLCMetaData = VLCMetaData()

    @objc public var fullscreenSessionRequested: Bool = true
    @objc public var playerIsSetup: Bool = false
    @objc public var playAsAudio: Bool = false
    @objc public var openedLocalURLs: NSMutableArray = NSMutableArray()

    #if os(iOS)
    @objc public var renderer: VLCRendererItem?
    #endif

    @objc public private(set) var currentAspectRatio: Int = 0

    @objc public var playerDisplayController: VLCPlayerDisplayController = VLCPlayerDisplayController()

    @objc public private(set) var sleepTimer: Timer?

    /// Adjust filter wrapper. Constructed lazily in `startPlayback`
    /// against the live media player's filter; kept separate so the
    /// VideoFiltersView UI can rebind across stops.
    @objc public var adjustFilter: PlaybackServiceAdjustFilter!

    // MARK: Private state

    private let _playbackSessionManagementLock = NSLock()
    private var _mediaPlayer: VLCMediaPlayer!
    private var _listPlayer: VLCMediaListPlayer!
    private var _backgroundDummyPlayer: VLCMediaPlayer!

    private var _shouldResumePlaying = false
    private var _sessionWillRestart = false
    private var _itemInMediaListToBePlayedFirst: Int = -1
    private var _pathToExternalSubtitlesFile: String?

    private var _isInFillToScreen = false
    private var _previousAspectRatio: Int = 0

    private var _videoOutputViewWrapper: UIView?
    private var _actualVideoOutputView: UIView?
    private var _preBackgroundWrapperView: UIView?

    private var _majorPositionChangeInProgress: Int = 0
    private var _externalAudioPlaybackDeviceConnected = false

    private var _playbackCompletion: ((Bool) -> Void)?

    private var _currentIndex: Int = 0
    private var _shuffledOrder: NSMutableArray = NSMutableArray()
    private var _shuffleMode = false

    private var _openInMiniPlayer = false
    private var _primaryVideoSubtitleTrackIndex: Int = -1
    private var _secondaryVideoSubtitleTrackIndex: Int = -1

    // PiP plumbing — VLCKit hands us its `pipController` once the
    // drawable is realized. Strong refs are weak/atomic in upstream;
    // Swift doesn't have property atomics, so the mainactor hop in
    // `mediaPlayerStateChanged` is what we rely on for safety.
    // tvOS doesn't ship `VLCPictureInPictureDrawable`, so PiP is
    // gated to iOS only.
    #if os(iOS)
    private weak var pipController: VLCPictureInPictureWindowControlling?
    @objc public private(set) var isPipEnabled: Bool = false
    private var pipMediaController: PictureInPictureMediaController?
    #endif

    // MARK: Singleton

    nonisolated(unsafe) private static let _sharedInstance: PlaybackService = PlaybackService()

    /// Upstream call site: `PlaybackService.sharedInstance()`. We
    /// expose the singleton through a class method (the property
    /// would shadow it) to match that exactly.
    @objc public class func sharedInstance() -> PlaybackService { _sharedInstance }

    // MARK: Init

    public override init() {
        super.init()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(audioSessionRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        nc.addObserver(self, selector: #selector(applicationWillResignActive(_:)),
                       name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)),
                       name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(applicationWillEnterForeground(_:)),
                       name: UIApplication.willEnterForegroundNotification, object: nil)

        // Off-screen vout view, matching upstream's init-time creation
        // (VLCPlaybackService.m line ~284). Persistent across plays so
        // libvlc's drawable surface lives in a stable parent and just
        // gets reparented under the host wrapper.
        _actualVideoOutputView = UIView(frame: UIScreen.main.bounds)
        _actualVideoOutputView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _actualVideoOutputView?.autoresizesSubviews = true

        // Background-keepalive: a separate dummy player loaded with
        // /dev/zero so AVAudioSession stays held while the real media
        // is paused (matches upstream chromecast continuity behaviour).
        _backgroundDummyPlayer = VLCMediaPlayer(options: ["--demux=rawaud"])
        _backgroundDummyPlayer.media = VLCMedia(path: "/dev/zero")

        // Bind the adjust-filter wrapper eagerly to the dummy player's
        // filter so the player VC's `viewDidLoad` (which reads
        // `playbackService.adjustFilter.isEnabled`) doesn't crash on
        // an uninitialised IUO. `startPlayback` rebinds it to the
        // real list player's filter once that exists.
        adjustFilter = PlaybackServiceAdjustFilter(_backgroundDummyPlayer.adjustFilter)

        DispatchQueue.main.async { [weak self] in
            self?._externalAudioPlaybackDeviceConnected = self?.isExternalAudioPlaybackDeviceConnected() ?? false
        }
    }

    deinit {
        for url in openedLocalURLs {
            (url as? URL)?.stopAccessingSecurityScopedResource()
        }
        if _mediaPlayer != nil {
            _mediaPlayer.removeObserver(self, forKeyPath: "time")
        }
    }

    // MARK: - Computed read-onlys

    @objc public var currentlyPlayingMedia: VLCMedia? { _mediaPlayer?.media }
    @objc public var mediaDuration: Int { Int(_mediaPlayer?.media?.length.intValue ?? 0) }
    @objc public var mediaLength: VLCTime? { _mediaPlayer?.media?.length }
    @objc public var isPlaying: Bool { _mediaPlayer?.isPlaying ?? false }
    @objc public var isSeekable: Bool { _mediaPlayer?.isSeekable ?? false }
    @objc public var playbackTime: NSNumber { NSNumber(value: _mediaPlayer?.time.value?.intValue ?? 0) }

    @objc public var isShuffleMode: Bool {
        get { _shuffleMode }
        set { setShuffleMode(newValue) }
    }

    @objc public var repeatMode: VLCRepeatMode {
        get { _listPlayer?.repeatMode ?? .doNotRepeat }
        set { setRepeatMode(newValue) }
    }

    @objc public var playbackRate: Float {
        get { _mediaPlayer?.rate ?? 1.0 }
        set {
            _mediaPlayer?.rate = newValue
            metadata.playbackRate = NSNumber(value: _mediaPlayer?.rate ?? 1.0)
        }
    }

    @objc public var audioDelay: Float {
        get { Float(_mediaPlayer?.currentAudioPlaybackDelay ?? 0) / 1000.0 }
        set { _mediaPlayer?.currentAudioPlaybackDelay = Int(newValue * 1000.0) }
    }

    @objc public var playbackPosition: Float {
        get { Float(_mediaPlayer?.position ?? 0) }
        set {
            _mediaPlayer?.position = Double(newValue)
            _majorPositionChangeInProgress = 1
        }
    }

    @objc public var subtitleDelay: Float {
        get { Float(_mediaPlayer?.currentVideoSubTitleDelay ?? 0) / 1000.0 }
        set { _mediaPlayer?.currentVideoSubTitleDelay = Int(newValue * 1000.0) }
    }

    @objc public var preAmplification: CGFloat {
        get { CGFloat(_mediaPlayer?.equalizer?.preAmplification ?? 0) }
        set { _mediaPlayer?.equalizer?.preAmplification = Float(newValue) }
    }

    @objc public var currentMediaHasChapters: Bool {
        guard let player = _mediaPlayer else { return false }
        return player.numberOfTitles > 1 ||
               player.numberOfChapters(forTitle: player.currentTitleIndex) > 1
    }

    @objc public var currentMediaHasTrackToChooseFrom: Bool {
        guard let player = _mediaPlayer else { return false }
        return (player.audioTracks.count) > 2 || (player.videoTracks.count) >= 1
    }

    @objc public var currentMediaIs360Video: Bool { false }
    @objc public var isNextMediaAvailable: Bool {
        guard mediaList.count > 1 else { return false }
        return _currentIndex < mediaList.count - 1
    }

    // MARK: - Tracks

    @objc public var indexOfCurrentAudioTrack: Int {
        guard let tracks = _mediaPlayer?.audioTracks else { return -1 }
        for (i, track) in tracks.enumerated() where track.isSelected {
            return i
        }
        return -1
    }

    @objc public var indexOfCurrentPrimaryVideoSubtitleTrack: Int { _primaryVideoSubtitleTrackIndex }
    @objc public var indexOfCurrentSecondaryVideoSubtitleTrack: Int { _secondaryVideoSubtitleTrackIndex }

    @objc public var indexOfCurrentTitle: Int { Int(_mediaPlayer?.currentTitleIndex ?? 0) }
    @objc public var indexOfCurrentChapter: Int { Int(_mediaPlayer?.currentChapterIndex ?? 0) }
    @objc public var currentTitleDescription: VLCMediaPlayer.TitleDescription? { _mediaPlayer?.currentTitleDescription }
    @objc public var currentChapterDescription: VLCMediaPlayer.ChapterDescription? { _mediaPlayer?.currentChapterDescription }
    @objc public var numberOfVideoTracks: Int { _mediaPlayer?.videoTracks.count ?? 0 }
    @objc public var numberOfAudioTracks: Int { (_mediaPlayer?.audioTracks.count ?? 0) + 2 }
    @objc public var numberOfVideoSubtitlesIndexes: Int { (_mediaPlayer?.textTracks.count ?? 0) + 3 }
    @objc public var numberOfTitles: Int { Int(_mediaPlayer?.numberOfTitles ?? 0) }
    @objc public var numberOfChaptersForCurrentTitle: Int {
        guard let p = _mediaPlayer else { return 0 }
        return Int(p.numberOfChapters(forTitle: p.currentTitleIndex))
    }

    // MARK: - Playback control

    @objc public func play()      { _listPlayer?.play() }
    @objc public func pause()     { _listPlayer?.pause() }
    @objc public func playPause() { (_mediaPlayer?.isPlaying ?? false) ? pause() : play() }
    @objc public func nextFrame() {
        // VLCKit 4 dropped the `nextFrame` convenience. Approximate
        // by pausing and bumping the time forward by ~33ms (one
        // frame at 30fps). Good enough for the rare frame-step UX.
        guard let p = _mediaPlayer else { return }
        p.pause()
        p.time = VLCTime(int: p.time.intValue + 33)
    }

    @objc public func playedTime() -> VLCTime { _mediaPlayer?.time ?? VLCTime(int: 0) }
    @objc public func remainingTime() -> VLCTime { _mediaPlayer?.remainingTime ?? VLCTime(int: 0) }

    @objc public func jumpForward(_ interval: Int32) {
        _mediaPlayer?.jumpForward(Double(interval))
    }

    @objc public func jumpBackward(_ interval: Int32) {
        _mediaPlayer?.jumpBackward(Double(interval))
    }

    @objc public func shortJumpForward()  { _mediaPlayer?.shortJumpForward() }
    @objc public func shortJumpBackward() { _mediaPlayer?.shortJumpBackward() }

    @objc @discardableResult public func next() -> Bool {
        guard mediaList.count > 0 else { return false }
        if _currentIndex < mediaList.count - 1 {
            playItem(at: UInt(_currentIndex + 1))
            return true
        }
        return false
    }

    @objc @discardableResult public func previous() -> Bool {
        guard _currentIndex > 0 else { return false }
        playItem(at: UInt(_currentIndex - 1))
        return true
    }

    @objc public func playItem(at index: UInt) {
        let list = _shuffleMode ? (shuffledList ?? mediaList) : mediaList
        guard index < UInt(list.count), let media = list.media(at: index) else { return }
        _listPlayer?.playItem(at: NSNumber(value: index))
        _mediaPlayer?.media = media
        _currentIndex = Int(list.index(of: media))
        delegate?.prepare?(forMediaPlayback: self)
    }

    @objc public func toggleRepeatMode() {
        let next: VLCRepeatMode
        switch repeatMode {
        case .repeatAllItems: next = .doNotRepeat
        case .doNotRepeat:    next = .repeatCurrentItem
        case .repeatCurrentItem: next = .repeatAllItems
        @unknown default: next = .doNotRepeat
        }
        setRepeatMode(next)
    }

    public func setRepeatMode(_ mode: VLCRepeatMode) {
        _listPlayer?.repeatMode = mode
        delegate?.playModeUpdated?()
        NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackModeUpdated), object: self)
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: kVLCPlayerShouldRememberState) {
            defaults.set(mode.rawValue, forKey: kVLCPlayerIsRepeatEnabled)
        }
    }

    @objc public func setShuffleMode(_ shuffle: Bool) {
        _shuffleMode = shuffle
        if shuffle {
            shuffleMediaList()
        }
        delegate?.playModeUpdated?()
        NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServiceShuffleModeUpdated), object: self)
    }

    private func shuffleMediaList() {
        // Minimal Fisher-Yates on the index array. Upstream tracks
        // both an ordered shuffle index list AND a parallel
        // VLCMediaList; we keep that shape so the queue UI can read
        // either end.
        let n = mediaList.count
        guard n > 1 else { return }
        var indices = (0..<n).map { UInt($0) }
        for i in stride(from: n - 1, to: 0, by: -1) {
            let j = Int.random(in: 0...i)
            indices.swapAt(i, j)
        }
        let shuffled = VLCMediaList()
        for idx in indices {
            if let media = mediaList.media(at: idx) {
                shuffled.add(media)
            }
        }
        shuffledList = shuffled
    }

    // MARK: - Tracks

    @objc public func selectAudioTrack(at index: Int) {
        _mediaPlayer?.selectTrack(at: index, type: .audio)
    }

    @objc public func disableAudio() {
        _mediaPlayer?.deselectAllAudioTracks()
    }

    @objc public func selectPrimaryVideoSubtitle(at index: Int) {
        guard let tracks = _mediaPlayer?.textTracks, index >= 0, index < tracks.count else { return }
        if _secondaryVideoSubtitleTrackIndex == index {
            _secondaryVideoSubtitleTrackIndex = -1
        }
        _primaryVideoSubtitleTrackIndex = index
        syncVideoSubtitleState()
    }

    @objc public func selectSecondaryVideoSubtitle(at index: Int) {
        guard let tracks = _mediaPlayer?.textTracks, index >= 0, index < tracks.count else { return }
        if _primaryVideoSubtitleTrackIndex == index {
            _primaryVideoSubtitleTrackIndex = -1
        }
        _secondaryVideoSubtitleTrackIndex = index
        syncVideoSubtitleState()
    }

    @objc public func disablePrimaryVideoSubtitle() {
        _primaryVideoSubtitleTrackIndex = -1
        syncVideoSubtitleState()
    }

    @objc public func disableSecondaryVideoSubtitle() {
        _secondaryVideoSubtitleTrackIndex = -1
        syncVideoSubtitleState()
    }

    @objc public func syncVideoSubtitleState() {
        guard let player = _mediaPlayer else { return }
        let tracks = player.textTracks
        var toSelect: [VLCMediaPlayer.Track] = []
        if _primaryVideoSubtitleTrackIndex >= 0, _primaryVideoSubtitleTrackIndex < tracks.count {
            toSelect.append(tracks[_primaryVideoSubtitleTrackIndex])
        }
        if _secondaryVideoSubtitleTrackIndex >= 0, _secondaryVideoSubtitleTrackIndex < tracks.count {
            toSelect.append(tracks[_secondaryVideoSubtitleTrackIndex])
        }
        player.selectTextTracks(toSelect)
    }

    @objc public func disableSubtitlesIfNeeded() {
        if UserDefaults.standard.bool(forKey: "kVLCSettingDisableSubtitles") {
            disablePrimaryVideoSubtitle()
            disableSecondaryVideoSubtitle()
        }
    }

    @objc public func selectTitle(at index: Int) {
        guard let player = _mediaPlayer, index >= 0, index < Int(player.numberOfTitles) else { return }
        player.currentTitleIndex = Int32(index)
    }

    @objc public func selectChapter(at index: Int) {
        guard index >= 0, index < numberOfChaptersForCurrentTitle else { return }
        _mediaPlayer?.currentChapterIndex = Int32(index)
    }

    @objc public func audioTrackName(at index: Int) -> String {
        guard let tracks = _mediaPlayer?.audioTracks else { return "" }
        if index < tracks.count {
            return tracks[index].trackName
        }
        if index == tracks.count {
            return NSLocalizedString("SELECT_AUDIO_FROM_FILES", comment: "")
        }
        return ""
    }

    @objc public func videoSubtitleName(at index: Int) -> String {
        guard let tracks = _mediaPlayer?.textTracks else { return "" }
        if index < tracks.count {
            return tracks[index].trackName
        }
        if index == tracks.count {
            return NSLocalizedString("SELECT_SUBTITLE_FROM_FILES", comment: "")
        }
        return ""
    }

    @objc public func titleDescription(at index: Int) -> VLCMediaPlayer.TitleDescription? {
        guard let descs = _mediaPlayer?.titleDescriptions, index >= 0, index < descs.count else { return nil }
        return descs[index]
    }

    @objc public func chapterDescription(at index: Int) -> VLCMediaPlayer.ChapterDescription? {
        guard let player = _mediaPlayer else { return nil }
        let descs = player.chapterDescriptions(ofTitle: player.currentTitleIndex)
        guard index >= 0, index < descs.count else { return nil }
        return descs[index]
    }

    // MARK: - Aspect ratio / 360 / viewport

    @objc public func switchAspectRatio(_ toggleFullScreen: Bool) {
        // Slim port: cycle through default → fillToScreen → 4:3 → 16:10 → 16:9
        currentAspectRatio = (currentAspectRatio + 1) % 5
        delegate?.playbackServiceDidSwitchAspectRatio?(currentAspectRatio)
    }

    public func setCurrentAspectRatio(_ ratio: Int) {
        currentAspectRatio = ratio
        delegate?.playbackServiceDidSwitchAspectRatio?(ratio)
    }

    @objc public var yaw: CGFloat   { 0 }
    @objc public var pitch: CGFloat { 0 }
    @objc public var roll: CGFloat  { 0 }
    @objc public var fov: CGFloat   { 80 }

    @objc public func updateViewpoint(yaw: CGFloat, pitch: CGFloat, roll: CGFloat, fov: CGFloat, absolute: Bool) -> Bool {
        false
    }

    @objc public func currentMediaProjection() -> Int { 0 }

    // MARK: - PiP

    @objc public func togglePictureInPicture() {
        #if os(iOS)
        if isPipEnabled {
            pipController?.stopPictureInPicture()
        } else {
            pipController?.startPictureInPicture()
        }
        #endif
    }

    // MARK: - Misc

    @objc public func setNeedsMetadataUpdate() {
        // Hop to main: VLCMediaDelegate callbacks fire on libvlc worker
        // threads, and the delegate (player VC) is main-actor isolated.
        // Calling its `displayMetadata` from a background thread traps.
        if Thread.isMainThread {
            performMetadataUpdate()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performMetadataUpdate()
            }
        }
    }

    private func performMetadataUpdate() {
        guard let player = _mediaPlayer else { return }
        let mlMedia = VLCMLMedia(forPlaying: player.media)
        metadata.updateMetadata(from: mlMedia, mediaPlayer: player)
        delegate?.displayMetadata?(for: self, metadata: metadata)
    }

    @objc public func recoverDisplayedMetadata() { setNeedsMetadataUpdate() }
    @objc public func recoverPlaybackState() {
        delegate?.prepare?(forMediaPlayback: self)
        setNeedsMetadataUpdate()
    }

    @objc public func savePlaybackState() {
        // Upstream persists last-played time into VLCMediaLibraryKit;
        // we leave this as a no-op since we don't ship that database.
        // Hosts should sync progress back to their backend separately.
    }

    @objc public func saveSnapshot(completion: @escaping (Bool, Error?) -> Void) {
        completion(false, nil)
    }

    @objc public func setAmplification(_ amplification: CGFloat, forBand band: UInt32) {
        // VLCKit 4 dropped this convenience on VLCAudioEqualizer.
        // Caller (the equalizer UI) is excluded from our build.
    }

    @objc public func scheduleSleepTimer(withInterval interval: TimeInterval) {
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.stopPlayback()
        }
    }

    @objc public func performNavigationAction(_ action: VLCMediaPlaybackNavigationAction) {
        _mediaPlayer?.perform(action)
    }

    @objc public func setPlayerHidden(_ hidden: Bool) {
        // No-op — host VC controls its own visibility.
    }

    @objc public func isPlayingOnExternalScreen() -> Bool { false }

    @objc public func mediaListContains(_ url: URL) -> Bool {
        for i in 0..<mediaList.count {
            if mediaList.media(at: UInt(i))?.url == url { return true }
        }
        return false
    }

    @objc public func removeMediaFromMediaList(at index: UInt) {
        guard index < UInt(mediaList.count) else { return }
        mediaList.removeMedia(at: index)
    }

    @objc public func selectedEqualizerProfile() -> IndexPath {
        IndexPath(row: 0, section: 0)
    }

    @objc public func setAudioPassthrough(_ shouldPass: Bool) {
        _mediaPlayer?.audio?.passthrough = shouldPass
    }

    @objc public func restoreAudioAndSubtitleTrack() {
        // Upstream rehydrates from VLCMediaLibraryKit. No-op in our slim path.
    }

    /// Verbatim keys + defaults from upstream's `VLCConstants.h`:
    ///   kVLCSettingNetworkCaching   = "network-caching"  default 999
    ///   kVLCSettingTextEncoding     = "subsdec-encoding" default "Windows-1252"
    ///   kVLCSettingSkipLoopFilter   = "avcodec-skiploopfilter" default 0
    ///   kVLCSettingHardwareDecoding = "codec"            default ""
    ///   kVLCSettingNetworkRTSPTCP   = "rtsp-tcp"
    ///   kVLCSettingNetworkRTSPHTTP  = "rtsp-http"
    @objc public var mediaOptionsDictionary: [AnyHashable: Any]? {
        let defaults = UserDefaults.standard
        return [
            "network-caching": defaults.object(forKey: "network-caching") ?? 999,
            "subsdec-encoding": defaults.object(forKey: "subsdec-encoding") ?? "Windows-1252",
            "avcodec-skiploopfilter": defaults.object(forKey: "avcodec-skiploopfilter") ?? 0,
            "codec": defaults.object(forKey: "codec") ?? "",
            "rtsp-tcp": defaults.object(forKey: "rtsp-tcp") ?? false,
            "rtsp-http": defaults.object(forKey: "rtsp-http") ?? false
        ]
    }

    // MARK: - External public API: queue + start

    @objc public func playMediaList(
        _ list: VLCMediaList,
        firstIndex index: Int,
        subtitlesFilePath: String?
    ) {
        playMediaList(list, firstIndex: index, subtitlesFilePath: subtitlesFilePath, completion: nil)
    }

    @objc public func playMediaList(
        _ list: VLCMediaList,
        firstIndex index: Int,
        subtitlesFilePath: String?,
        completion: ((Bool) -> Void)?
    ) {
        _playbackCompletion = completion
        mediaList = list
        _itemInMediaListToBePlayedFirst = Int(index)
        _pathToExternalSubtitlesFile = subtitlesFilePath
        _sessionWillRestart = playerIsSetup
        if playerIsSetup {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    @objc public func startPlayback() {
        guard _playbackSessionManagementLock.try() else { return }
        if playerIsSetup {
            _playbackSessionManagementLock.unlock()
            return
        }
        if mediaList.count == 0 {
            _playbackSessionManagementLock.unlock()
            stopPlayback()
            return
        }

        if _listPlayer == nil {
            _listPlayer = VLCMediaListPlayer(drawable: self)
            _mediaPlayer = _listPlayer.mediaPlayer
            _mediaPlayer.addObserver(self, forKeyPath: "time", options: [], context: nil)
        }
        _listPlayer.delegate = self
        _mediaPlayer.delegate = self

        #if os(iOS)
        if pipMediaController == nil {
            pipMediaController = PictureInPictureMediaController(_mediaPlayer)
        }
        #endif

        let defaults = UserDefaults.standard
        let speed = defaults.float(forKey: "playback-speed-custom")
        if speed != 0 { _mediaPlayer.rate = speed }

        _listPlayer.mediaList = mediaList
        if defaults.bool(forKey: kVLCPlayerShouldRememberState) {
            let raw = defaults.integer(forKey: kVLCPlayerIsRepeatEnabled)
            _listPlayer.repeatMode = VLCRepeatMode(rawValue: raw) ?? .doNotRepeat
        }

        _playbackSessionManagementLock.unlock()
        _playNewMedia()
    }

    private func _playNewMedia() {
        guard _playbackSessionManagementLock.try() else { return }

        if _itemInMediaListToBePlayedFirst == -1 {
            let count = mediaList.count
            if _shuffleMode, count > 0 {
                _itemInMediaListToBePlayedFirst = Int.random(in: 0..<max(1, count))
                shuffleMediaList()
            } else {
                _itemInMediaListToBePlayedFirst = 0
            }
        }

        guard let media = mediaList.media(at: UInt(_itemInMediaListToBePlayedFirst)) else {
            _playbackSessionManagementLock.unlock()
            return
        }
        media.parse(options: [.parseLocal, .parseNetwork])
        media.delegate = self
        if let opts = mediaOptionsDictionary {
            media.addOptions(opts)
        }

        _listPlayer.playItem(at: NSNumber(value: _itemInMediaListToBePlayedFirst))
        _currentIndex = _itemInMediaListToBePlayedFirst

        delegate?.prepare?(forMediaPlayback: self)

        currentAspectRatio = 0
        _mediaPlayer.videoAspectRatio = nil

        if let path = _pathToExternalSubtitlesFile {
            let url = URL(string: path) ?? URL(fileURLWithPath: path)
            _mediaPlayer.addPlaybackSlave(url, type: .subtitle, enforce: true)
        }

        playerIsSetup = true
        _playbackSessionManagementLock.unlock()
    }

    @objc public func stopPlayback() {
        guard _playbackSessionManagementLock.try() else { return }
        if playerIsSetup {
            _isInFillToScreen = false
            if let player = _mediaPlayer, player.media != nil, player.state != .stopped {
                player.pause()
                savePlaybackState()
                player.stop()
            }

            if let completion = _playbackCompletion {
                let player = _mediaPlayer!
                var withError = false
                if player.state == .stopped, let media = player.media {
                    let stats = media.statistics
                    withError = (stats.decodedAudio == 0) && (stats.decodedVideo == 0)
                } else {
                    withError = (player.state == .error)
                }
                withError = withError && !_sessionWillRestart
                completion(!withError)
            }
            shuffledList = nil
            if !_sessionWillRestart {
                mediaList = VLCMediaList()
                _listPlayer?.mediaList = mediaList
                for url in openedLocalURLs {
                    (url as? URL)?.stopAccessingSecurityScopedResource()
                }
                openedLocalURLs.removeAllObjects()
            }
            playerIsSetup = false
        }
        _playbackSessionManagementLock.unlock()
        NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackDidStop), object: self)
        if _sessionWillRestart {
            DispatchQueue.main.async { [weak self] in
                self?._sessionWillRestart = false
                self?.startPlayback()
            }
        }
    }

    @objc public func addAudioToCurrentPlayback(from url: URL) {
        _mediaPlayer?.addPlaybackSlave(url, type: .audio, enforce: true)
    }

    @objc public func addSubtitlesToCurrentPlayback(from url: URL) {
        _mediaPlayer?.addPlaybackSlave(url, type: .subtitle, enforce: true)
    }

    // MARK: - Display controller

    public func setPlayerDisplayController(_ controller: VLCPlayerDisplayController) {
        self.playerDisplayController = controller
    }

    private func setVideoOutputView(_ view: UIView?) {
        // Verbatim port of upstream's setVideoOutputView. Stays as
        // close to the Obj-C original as possible — frame copy +
        // autoresizing, no SwiftUI Auto Layout layered on top.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let videoOutputView = view {
                if self._actualVideoOutputView?.superview != nil {
                    self._actualVideoOutputView?.removeFromSuperview()
                }
                self._actualVideoOutputView?.frame = CGRect(origin: .zero, size: videoOutputView.frame.size)
                if let actual = self._actualVideoOutputView {
                    videoOutputView.addSubview(actual)
                    actual.layoutSubviews()
                    actual.updateConstraints()
                    actual.setNeedsLayout()
                }
            } else {
                self._actualVideoOutputView?.removeFromSuperview()
            }
            self._videoOutputViewWrapper = view
        }
    }

    // MARK: - Notifications

    @objc private func audioSessionRouteChange(_ notification: Notification) {}
    @objc private func handleInterruption(_ notification: Notification) {}
    @objc private func applicationWillResignActive(_ notification: Notification) {}
    @objc private func applicationDidEnterBackground(_ notification: Notification) {}
    @objc private func applicationWillEnterForeground(_ notification: Notification) {}

    private func isExternalAudioPlaybackDeviceConnected() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == .bluetoothA2DP ||
            $0.portType == .bluetoothLE ||
            $0.portType == .bluetoothHFP ||
            $0.portType == .airPlay ||
            $0.portType == .headphones
        }
    }
}

// MARK: - KVO

extension PlaybackService {
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.playbackPositionUpdated?(self)
            if self._majorPositionChangeInProgress >= 1 {
                self.metadata.updateExposedTiming(from: self._mediaPlayer)
                self._majorPositionChangeInProgress += 1
                if self._majorPositionChangeInProgress == 10 {
                    self._majorPositionChangeInProgress = 0
                }
            }
            NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackPositionUpdated), object: self)
        }
    }
}

// MARK: - VLCMediaPlayerDelegate

extension PlaybackService: VLCMediaPlayerDelegate {
    public func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        // VLCKit 4 delivers the state directly (not a Notification) —
        // bridging to a Notification-shaped Swift signature silently
        // dropped the callback and stalled all state-driven UI.
        let state = newState
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .opening:
                NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackDidStart), object: self,
                                                userInfo: [kVLCPlayerOpenInMiniPlayer: self._openInMiniPlayer])
                self._openInMiniPlayer = false
            case .playing:
                NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackDidResume), object: self)
            case .paused:
                self.savePlaybackState()
                NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackDidPause), object: self)
            case .error:
                NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackDidFail), object: self)
                self._sessionWillRestart = false
                self.stopPlayback()
            case .stopped:
                // Upstream's `[list indexOfMedia:media] == list.count - 1`
                // wraps around in Obj-C when count is 0. Swift's
                // `UInt(list.count - 1)` traps on negative — guard explicitly.
                if let list = self._listPlayer.mediaList,
                   let media = self._mediaPlayer.media,
                   list.count > 0,
                   Int(list.index(of: media)) == list.count - 1,
                   self.repeatMode == .doNotRepeat {
                    self._sessionWillRestart = false
                    self.stopPlayback()
                }
            default:
                break
            }
            self.mediaPlayerState = state
            self.delegate?.mediaPlayerStateChanged?(state,
                                                    isPlaying: self._mediaPlayer?.isPlaying ?? false,
                                                    currentMediaHasTrackToChooseFrom: self.currentMediaHasTrackToChooseFrom,
                                                    currentMediaHasChapters: self.currentMediaHasChapters,
                                                    for: self)
            self.setNeedsMetadataUpdate()
        }
    }
}

// MARK: - VLCMediaListPlayerDelegate

extension PlaybackService: VLCMediaListPlayerDelegate {
    public func mediaListPlayer(_ player: VLCMediaListPlayer, nextMedia media: VLCMedia) {
        delegate?.playbackService?(self, nextMedia: media)
        NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackDidMoveOnToNextItem), object: self)
    }
}

// MARK: - VLCMediaDelegate

extension PlaybackService: VLCMediaDelegate {
    public func mediaMetaDataDidChange(_ aMedia: VLCMedia) {
        setNeedsMetadataUpdate()
        NotificationCenter.default.post(name: Notification.Name(VLCPlaybackServicePlaybackMetadataDidChange), object: self)
    }
}

// `extension PlaybackService: EqualizerViewDelegate` lives in
// VLCPlayerKit/Stubs/MoreOptionsSheetStubs.swift so the conformance
// is only present in the iOS UI module — tvOS doesn't need it.

// MARK: - VLCDrawable / VLCPictureInPictureDrawable

extension PlaybackService: VLCDrawable {
    public func addSubview(_ view: UIView) {
        _actualVideoOutputView?.addSubview(view)
        view.frame = _actualVideoOutputView?.bounds ?? .zero
    }

    public func bounds() -> CGRect {
        _actualVideoOutputView?.bounds ?? .zero
    }
}

#if os(iOS)
extension PlaybackService: VLCPictureInPictureDrawable {
    public func mediaController() -> (any VLCPictureInPictureMediaControlling)? {
        pipMediaController
    }

    public func pictureInPictureReady() -> ((any VLCPictureInPictureWindowControlling)?) -> Void {
        // PlaybackService is the process singleton — strong-capturing
        // self in the PiP callbacks is fine and side-steps Swift 6's
        // send-self diagnostic that fires when [weak self] crosses
        // structured-concurrency boundaries even on Sendable types.
        return { [unowned self] controller in
            self.pipController = controller
            controller?.stateChangeEventHandler = { [unowned self] isStarted in
                DispatchQueue.main.async { [unowned self] in
                    self.isPipEnabled = isStarted
                    self.delegate?.pictureInPictureStateDidChange?(enabled: isStarted)
                }
            }
        }
    }
}
#endif

#endif
