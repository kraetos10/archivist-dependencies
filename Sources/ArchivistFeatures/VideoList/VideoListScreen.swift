#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct VideoListScreen: View {
    @Bindable public var store: StoreOf<VideoListReducer>

    public init(store: StoreOf<VideoListReducer>) {
        self.store = store
    }

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
