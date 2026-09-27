#if os(watchOS)
import Foundation

/// A channel's videos are the video list narrowed to that channel, so the
/// channel screen reuses the list's loading, paging and player handling.
public typealias WatchChannelDetailViewModel = WatchVideoListViewModel
#endif
