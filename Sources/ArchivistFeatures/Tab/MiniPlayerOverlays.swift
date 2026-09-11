#if os(iOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

// MARK: - Mini Player Host Overlay

/// The floating mini player itself. It hosts ONLY the persistent player
/// surface owned by `PlayerManager` — never a scaled-down copy of the
/// video detail screen. Reparenting that one surface is what lets the
/// video carry on playing across the transition.
struct MiniPlayerHostOverlay: View {
    let store: StoreOf<TabReducer>
    let bottomInset: CGFloat

    var body: some View {
        Group {
            if let detail = store.miniPlayer, store.isMiniPlayerMinimised {
                DraggableMiniPlayerOverlay(bottomInset: bottomInset) {
                    MiniPlayerView(
                        title: detail.video.title,
                        onTap: { store.send(.miniPlayerTapped) },
                        onClose: { store.send(.miniPlayerCloseTapped) }
                    )
                }
                .transition(.opacity)
            }
        }
        // The mini player arrives and leaves on reducer effects, which
        // carry no animation of their own, so fade it here instead.
        .animation(.easeInOut(duration: 0.2), value: store.miniPlayerAnimationKey)
    }
}

// MARK: - Expanded Mini Player Overlay

/// The full detail screen for the minimised video, shown when the user taps
/// the mini player back up. It renders the SAME persistent surface that was
/// just in the mini player, so expanding doesn't interrupt playback either.
///
/// It's an overlay rather than a push back onto a navigation stack because
/// the stack the video was originally opened from may well be in a tab the
/// user has since navigated away from.
struct ExpandedMiniPlayerOverlay: View {
    let store: StoreOf<TabReducer>

    var body: some View {
        Group {
            if let miniStore = store.scope(state: \.miniPlayer, action: \.miniPlayer),
               !store.isMiniPlayerMinimised {
                // No background of its own: `VideoDetailScreen` paints an
                // opaque one at rest and fades it out as it is dragged
                // down, and a slab of colour here would be all that fade
                // ever revealed. Without it the drag uncovers the tabs.
                NavigationStack {
                    VideoDetailScreen(store: miniStore)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.miniPlayerAnimationKey)
    }
}
#endif
