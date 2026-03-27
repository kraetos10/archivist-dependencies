import SwiftUI

public struct PlayerConfig: Equatable {
    public var position: CGFloat = .zero
    public var lastPosition: CGFloat = .zero
    public var progress: CGFloat = .zero
    public var showMiniPlayer: Bool = false

    public init(
        position: CGFloat = .zero,
        lastPosition: CGFloat = .zero,
        progress: CGFloat = .zero,
        showMiniPlayer: Bool = false
    ) {
        self.position = position
        self.lastPosition = lastPosition
        self.progress = progress
        self.showMiniPlayer = showMiniPlayer
    }

    public mutating func resetPosition() {
        position = .zero
        lastPosition = .zero
        progress = .zero
    }
}
