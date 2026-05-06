#if !os(tvOS)
import UIKit

@MainActor
@Observable
public final class OrientationLock {
    public static let shared = OrientationLock()

    public var orientationLock: UIInterfaceOrientationMask = .allButUpsideDown

    public init() {}

    public func lockPortrait() {
        orientationLock = .portrait
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            scene.requestGeometryUpdate(geometryPreferences)
        }
    }

    public func lockLandscape() {
        orientationLock = .landscape
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
            scene.requestGeometryUpdate(geometryPreferences)
        }
    }

    public func unlock() {
        orientationLock = .allButUpsideDown
    }

    /// Force-flip the interface between portrait and landscape regardless
    /// of the device's rotation lock. Used by the fullscreen player's
    /// rotate button so the user can switch orientation without going to
    /// Control Center.
    public func rotateFullscreen() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let isLandscape = scene.interfaceOrientation.isLandscape
        let target: UIInterfaceOrientationMask = isLandscape ? .portrait : .landscape
        orientationLock = target

        // Without `setNeedsUpdateOfSupportedInterfaceOrientations`, UIKit
        // serves the supported-orientations set it cached the first time
        // the scene rotated. After the first tap puts us in landscape
        // with `orientationLock = .landscape`, the second tap's geometry
        // request to portrait is then silently rejected because portrait
        // isn't in the cached set — the rotate button "only works once."
        // Force a re-query first, then request the new geometry.
        if let rootVC = scene.windows.first?.rootViewController {
            rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: target)
        scene.requestGeometryUpdate(prefs)
    }
}
#endif
