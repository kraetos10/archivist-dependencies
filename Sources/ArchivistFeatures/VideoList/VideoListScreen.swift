#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct VideoListScreen: View {
    @Bindable public var store: StoreOf<VideoListReducer>

    public init(store: StoreOf<VideoListReducer>) {
        self.store = store
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        if sizeClass == .regular {
            iPadVideoListScreen(store: store)
        } else {
            iPhoneVideoListScreen(store: store)
        }
    }
}
#endif
