#if os(tvOS)
import UIKit

/// The UIKit side of `TVPlayerPressView`: press and touch-surface capture.
final class TVPressTrackingView: UIView {
    var onTap: ((UIPress.PressType) -> Void)?
    var onHoldBegan: ((UIPress.PressType) -> Void)?
    var onHoldEnded: ((UIPress.PressType) -> Void)?
    var onScrubBegan: (() -> Void)?
    /// Horizontal translation as a fraction of this view's width.
    var onScrubChanged: ((CGFloat) -> Void)?
    /// `true` when the pan was cancelled rather than finished.
    var onScrubEnded: ((Bool) -> Void)?

    /// Threshold above which a Left/Right press is treated as a hold
    /// rather than a discrete tap.
    private let holdThreshold: Duration = .milliseconds(300)

    /// Presses whose length matters — held, they rewind / fast-forward.
    private static let holdTypes: Set<UIPress.PressType> = [.leftArrow, .rightArrow]
    /// Presses that are always a tap, dispatched on release.
    private static let tapTypes: Set<UIPress.PressType> = [
        .upArrow, .downArrow, .playPause, .select, .menu
    ]

    private var holdTimers: [UIPress.PressType: Task<Void, Never>] = [:]
    private var heldPresses: Set<UIPress.PressType> = []
    /// Presses that began on this view. A release only counts if its press
    /// did — Menu dismissing the speed picker must not also reach here as a
    /// fresh Menu and close the player.
    private var activePresses: Set<UIPress.PressType> = []

    override var canBecomeFocused: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        installScrubGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installScrubGesture()
    }

    private func installScrubGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        pan.cancelsTouchesInView = false
        addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            onScrubBegan?()
        case .changed:
            let width = max(bounds.width, 1)
            onScrubChanged?(recognizer.translation(in: self).x / width)
        case .ended:
            onScrubEnded?(false)
        case .cancelled, .failed:
            onScrubEnded?(true)
        default:
            break
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            if Self.holdTypes.contains(press.type) {
                activePresses.insert(press.type)
                schedule(press.type)
            } else if Self.tapTypes.contains(press.type) {
                activePresses.insert(press.type)
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            let type = press.type
            if Self.holdTypes.contains(type) {
                if activePresses.remove(type) != nil {
                    resolve(type)
                }
            } else if Self.tapTypes.contains(type) {
                if activePresses.remove(type) != nil {
                    onTap?(type)
                }
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesEnded(unhandled, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            let type = press.type
            if Self.holdTypes.contains(type) || Self.tapTypes.contains(type) {
                activePresses.remove(type)
                cancel(type)
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesCancelled(unhandled, with: event)
        }
    }

    private func schedule(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = Task { @MainActor [weak self, holdThreshold] in
            try? await Task.sleep(for: holdThreshold)
            guard let self, !Task.isCancelled else { return }
            self.heldPresses.insert(type)
            self.onHoldBegan?(type)
        }
    }

    private func resolve(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = nil
        if heldPresses.remove(type) != nil {
            onHoldEnded?(type)
        } else {
            onTap?(type)
        }
    }

    private func cancel(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = nil
        if heldPresses.remove(type) != nil {
            onHoldEnded?(type)
        }
    }
}
#endif
