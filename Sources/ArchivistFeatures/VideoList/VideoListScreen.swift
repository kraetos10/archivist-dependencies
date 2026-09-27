#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct VideoListScreen: View {
    @Bindable public var store: StoreOf<VideoListReducer>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(store: StoreOf<VideoListReducer>) {
        self.store = store
    }

    public var body: some View {
        // Size class, not device idiom: an iPad in a narrow multitasking
        // window gets the compact layout.
        if horizontalSizeClass == .regular {
            iPadVideoListScreen(store: store)
        } else {
            iPhoneVideoListScreen(store: store)
        }
    }
}
#endif
