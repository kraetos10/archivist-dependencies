import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture

// Typed `@Shared` keys for every `UserDefaults.standard` value the app
// persists, each with its one default. Use them as
// `@Shared(.autoPlayEnabled) var autoPlayEnabled` — never repeat the raw
// string and default at the call site.
//
// The child-mode PIN is deliberately absent: it lives in the Keychain via
// `PinStore`.
//
// Lives in ArchivistFeatures rather than ArchivistComponents because
// Components doesn't depend on Sharing, and `ChannelListFilter` /
// `DownloadSortOrder` are declared here.

// MARK: - Bool

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    /// Auto-advance to the next video when one finishes.
    public static var autoPlayEnabled: Self {
        Self[.appStorage("autoPlayEnabled"), default: true]
    }

    /// Auto-advance through a playlist.
    public static var autoPlayPlaylist: Self {
        Self[.appStorage("autoPlayPlaylist"), default: true]
    }

    /// Restart a playlist from the top after its last video.
    public static var loopPlaylist: Self {
        Self[.appStorage("loopPlaylist"), default: false]
    }

    /// Child mode on/off.
    public static var childModeEnabled: Self {
        Self[.appStorage(ChildMode.enabledKey), default: false]
    }

    /// The software-decode warning has been shown once already.
    public static var hasSeenSoftwareDecodeWarning: Self {
        Self[.appStorage("hasSeenSoftwareDecodeWarning"), default: false]
    }
}

// MARK: - Theme

extension SharedKey where Self == AppStorageKey<AppTheme>.Default {
    /// The selected colour theme. Stored as its `rawValue` under
    /// `AppTheme.storageKey`, so `AppTheme.current` reads the same value.
    public static var selectedAppTheme: Self {
        Self[.appStorage(AppTheme.storageKey), default: AppTheme.fallback]
    }
}

// MARK: - Filters and sort orders

extension SharedKey where Self == AppStorageKey<WatchFilter>.Default {
    /// The watch filter on the video list.
    public static var videoListWatchFilter: Self {
        Self[.appStorage("videoListWatchFilter"), default: .unwatched]
    }
}

extension SharedKey where Self == AppStorageKey<VideoSortOrder>.Default {
    /// The sort order for one watch-filter destination. Keyed per filter;
    /// the separator is `_` because KVO can't observe keys containing `.`.
    public static func videoListSortOrder(for filter: WatchFilter) -> Self {
        Self[.appStorage("videoListSortOrder_\(filter.rawValue)"), default: .published]
    }
}

extension SharedKey where Self == AppStorageKey<ChannelListFilter>.Default {
    /// The filter on the channels list.
    public static var channelsFilter: Self {
        Self[.appStorage("channelsFilter"), default: .all]
    }
}

extension SharedKey where Self == AppStorageKey<DownloadSortOrder>.Default {
    /// The sort order on the server downloads queue.
    public static var downloadsSortOrder: Self {
        Self[.appStorage("downloadsSortOrder"), default: .newestFirst]
    }
}
