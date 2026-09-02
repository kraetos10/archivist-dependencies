import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The playlist's entries, plus its loading and empty states.
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
            entries
        }
    }

    private var entries: some View {
        VStack(spacing: 0) {
            ForEach(store.entries) { entry in
                let isAvailable = entry.youtubeId
                    .map { store.availableVideoIDs.contains($0) } ?? false

                PlaylistEntryRow(
                    entry: entry,
                    thumbnailURL: entry.youtubeId.flatMap { store.entryThumbURLs[$0] },
                    isAvailable: isAvailable
                )
                .pressable {
                    if isAvailable {
                        send(.entryTapped(entry))
                    } else {
                        send(.queueServerDownloadTapped(entry))
                    }
                }
                #if !os(tvOS)
                .contextMenu {
                    entryMenu(entry)
                }
                #endif
                .transition(.asymmetric(
                    insertion: .identity,
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.default, value: store.entries.map(\.id))
        .padding(.bottom, 24)
    }

    #if !os(tvOS)
    @ViewBuilder
    private func entryMenu(_ entry: PlaylistEntry) -> some View {
        if let videoId = entry.youtubeId,
           let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
            ShareLink(item: url) {
                Label(
                    String.localised("generic.share", table: .generic),
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        Button {
            send(.downloadToDeviceTapped(entry))
        } label: {
            Label(
                String.localised("video.downloadToDevice", table: .videos),
                systemImage: "arrow.down.circle"
            )
        }

        Button {
            send(.markAsWatchedTapped(entry))
        } label: {
            Label(
                String.localised("video.markAsWatched", table: .videos),
                systemImage: "eye"
            )
        }

        if store.isCustomPlaylist {
            Button(role: .destructive) {
                send(.removeEntryTapped(entry))
            } label: {
                Label(
                    String.localised("video.removeFromPlaylist", table: .videos),
                    systemImage: "minus.circle"
                )
            }
        }
    }
    #endif
}
