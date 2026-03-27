#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct VideoDetailScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        TVVideoDetailScreen(store: store)
    }
}
#else
import ComposableArchitecture
import SwiftUI

public struct VideoDetailScreen: View {
    @Bindable var store: StoreOf<VideoDetailReducer>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public var body: some View {
        if horizontalSizeClass == .regular {
            iPadVideoDetailScreen(store: store)
        } else {
            iPhoneVideoDetailScreen(store: store)
        }
    }
}
#endif
