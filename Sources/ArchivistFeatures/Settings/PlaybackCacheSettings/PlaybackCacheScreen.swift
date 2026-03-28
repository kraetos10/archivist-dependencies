#if !os(watchOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PlaybackCacheReducer.self)
public struct PlaybackCacheScreen: View {
    @Bindable public var store: StoreOf<PlaybackCacheReducer>

    public init(store: StoreOf<PlaybackCacheReducer>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section {
                Toggle(isOn: $store.prebufferEnabled) {
                    Text(String.localised("video.vlcPrebuffer", table: .videos))
                    Text(String.localised("video.vlcPrebufferSubtitle", table: .videos))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if store.prebufferEnabled {
                    Toggle(isOn: $store.prebufferWifiOnly) {
                        Text(String.localised("video.prebuffer.wifiOnly", table: .videos))
                        Text(String.localised("video.prebuffer.wifiOnlySubtitle", table: .videos))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(String.localised("video.prebuffer.header", table: .videos))
            } footer: {
                Text(String.localised("video.prebuffer.footer", table: .videos))
            }

            Section {
                LabeledContent(String.localised("video.cache.totalSize", table: .videos)) {
                    Text(formattedSize)
                        .foregroundStyle(Color.Brand.secondary)
                }
                LabeledContent(String.localised("video.cache.videos", table: .videos)) {
                    Text("\(store.entryCount)")
                        .foregroundStyle(Color.Brand.secondary)
                }
                Button(role: .destructive) {
                    send(.clearCacheTapped)
                } label: {
                    Text(String.localised("video.cache.clear", table: .videos))
                }
                .disabled(store.entryCount == 0)
            } header: {
                Text(String.localised("video.cache.header", table: .videos))
            } footer: {
                Text(String.localised("video.cache.footer", table: .videos))
            }
        }
        .background(Color.Brand.primary)
        .navigationTitle(String.localised("video.cache.title", table: .videos))
        #if !os(tvOS)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { send(.viewDidAppear) }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: store.totalSize, countStyle: .file)
    }
}
#endif
