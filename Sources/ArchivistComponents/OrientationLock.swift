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
}
#endif
