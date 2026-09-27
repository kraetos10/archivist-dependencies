import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The playlist's entries, plus its loading and empty states.
///
/// The rows are the view's direct children (no wrapping stack), so inside the
/// screen's `LazyVStack` section they're built as they scroll in rather than
/// all up front.
@ViewAction(for: PlaylistDetailReducer.self)
struct PlaylistEntriesList: View {
    let store: StoreOf<PlaylistDetailReducer>

    var body: some View {
        if store.isLoadingEntries && store.entries.isEmpty {
            ProgressView()
                .tint(Color.Progress.tint)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        } else if store.entries.isEmpty && store.hasLoadedEntries {
            Text(String.localised("video.empty.noVideos", table: .videos))
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        } else {
            // Read once per pass: builds a dictionary over every entry.
            let thumbURLs = store.entryThumbURLs

            ForEach(store.entries) { entry in
                PlaylistEntryRow(
                    entry: entry,
                    thumbnailURL: entry.youtubeId.flatMap { thumbURLs[$0] },
                    isAvailable: store.state.isEntryAvailable(entry)
                )
                .pressable {
                    send(.entryTapped(entry))
                }
                #if !os(tvOS)
                .contextMenu {
                    PlaylistEntryMenu(
                        entry: entry,
                        allowsRemoval: store.isCustomPlaylist,
                        onDownloadToDevice: { send(.downloadToDeviceTapped(entry)) },
                        onMarkAsWatched: { send(.markAsWatchedTapped(entry)) },
                        onRemove: { send(.removeEntryTapped(entry)) }
                    )
                }
                #endif
                .transition(.asymmetric(
                    insertion: .identity,
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }

            Color.clear
                .frame(height: 24)
                .accessibilityHidden(true)
        }
    }
}

#if !os(tvOS)
/// The long-press menu on a playlist entry.
private struct PlaylistEntryMenu: View {
    let entry: PlaylistEntry
    let allowsRemoval: Bool
    let onDownloadToDevice: () -> Void
    let onMarkAsWatched: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if let url = entry.youtubeWatchURL {
            ShareLink(item: url) {
                Label(
                    String.localised("generic.share", table: .generic),
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        Button(
            String.localised("video.downloadToDevice", table: .videos),
            systemImage: "arrow.down.circle",
            action: onDownloadToDevice
        )

        Button(
            String.localised("video.markAsWatched", table: .videos),
            systemImage: "eye",
            action: onMarkAsWatched
        )

        if allowsRemoval {
            Button(
                String.localised("video.removeFromPlaylist", table: .videos),
                systemImage: "minus.circle",
                role: .destructive,
                action: onRemove
            )
        }
    }
}
#endif
