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
        #if os(tvOS)
        tvBody
        #else
        iOSBody
        #endif
    }

    // MARK: - iOS / iPadOS

    #if !os(tvOS)
    private var iOSBody: some View {
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
        .scrollContentBackground(.hidden)
        .navigationTitle(String.localised("video.cache.title", table: .videos))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { send(.viewDidAppear) }
    }
    #endif

    // MARK: - tvOS

    #if os(tvOS)
    private var tvBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                Text(String.localised("video.cache.title", table: .videos))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)

                tvPrebufferSection

                tvCacheSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 80)
            .padding(.bottom, 80)
        }
        .background(Color.Brand.primary)
        .onAppear { send(.viewDidAppear) }
    }

    private var tvPrebufferSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String.localised("video.prebuffer.header", table: .videos))
                .font(.title2)
                .fontWeight(.semibold)

            Toggle(isOn: $store.prebufferEnabled) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String.localised("video.prebuffer.tv.title", table: .videos))
                    Text(String.localised("video.prebuffer.tv.subtitle", table: .videos))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text(String.localised("video.prebuffer.tv.footer", table: .videos))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var tvCacheSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String.localised("video.cache.header", table: .videos))
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                Text(String.localised("video.cache.totalSize", table: .videos))
                Spacer()
                Text(formattedSize)
                    .foregroundStyle(Color.Brand.secondary)
            }
            HStack {
                Text(String.localised("video.cache.videos", table: .videos))
                Spacer()
                Text("\(store.entryCount)")
                    .foregroundStyle(Color.Brand.secondary)
            }

            Button(role: .destructive) {
                send(.clearCacheTapped)
            } label: {
                Text(String.localised("video.cache.clear", table: .videos))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .disabled(store.entryCount == 0)

            Text(String.localised("video.cache.footer", table: .videos))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
    #endif

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: store.totalSize, countStyle: .file)
    }
}
#endif
