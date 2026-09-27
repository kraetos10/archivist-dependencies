#if os(tvOS)
import UIKit

/// Adopts the persistent VLC surface as a pinned subview for the tvOS player.
final class TVVLCPlayerHostView: UIView {
    func adoptPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView else { return }
        if playerView.superview === self { return }

        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func detachPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView,
              playerView.superview === self else { return }
        playerView.removeFromSuperview()
    }
}
#endif
