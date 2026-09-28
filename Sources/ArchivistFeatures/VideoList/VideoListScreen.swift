#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct VideoListScreen: View {
    @Bindable public var store: StoreOf<VideoListReducer>
    public init(store: StoreOf<VideoListReducer>) {
        self.store = store
    }

    /// Device idiom, not size class. A Plus/Pro Max iPhone turns regular
    /// width in landscape, and switching view trees on that tears down
    /// anything presented from the old one — rotating a fullscreen video
    /// dismissed it. Presentation style (sheet vs popover) still follows
    /// size class; the layout family follows the device.
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    public var body: some View {
        if isIPad {
            iPadVideoListScreen(store: store)
        } else {
            iPhoneVideoListScreen(store: store)
        }
    }
}
#endif
