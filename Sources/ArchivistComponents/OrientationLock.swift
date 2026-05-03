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
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            scene.requestGeometryUpdate(geometryPreferences)
        }
    }

    public func lockLandscape() {
        orientationLock = .landscape
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
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
    /// Control Center. Sets `orientationLock` to the chosen mask so the
    /// AppDelegate honours the request, then requests a geometry update.
    public func rotateFullscreen() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let isLandscape = scene.interfaceOrientation.isLandscape
        let target: UIInterfaceOrientationMask = isLandscape ? .portrait : .landscape
        orientationLock = target
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: target)
        scene.requestGeometryUpdate(prefs)
    }
}
#endif
