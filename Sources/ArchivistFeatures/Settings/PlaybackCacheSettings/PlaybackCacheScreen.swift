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
                Toggle(isOn: Binding(store.withState { $0.$prebufferEnabled })) {
                    Text(String.localised("video.vlcPrebuffer", table: .videos))
                    Text(String.localised("video.vlcPrebufferSubtitle", table: .videos))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if store.prebufferEnabled {
                    Toggle(isOn: Binding(store.withState { $0.$prebufferWifiOnly })) {
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
                Picker(
                    String.localised("video.cache.sizeLimit", table: .videos),
                    selection: Binding(store.withState { $0.$cacheSizeLimitBytes })
                ) {
                    ForEach(PlaybackCache.cacheSizeLimitPresetsBytes, id: \.self) { value in
                        Text(Self.cacheLimitLabel(for: value)).tag(value)
                    }
                }
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
                // tvOS settings sub-screens title themselves in the content
                // (the navigation bar title is blanked under the tab bar).
                Text(String.localised("video.cache.title", table: .videos))
                    .font(.title2)
                    .fontWeight(.bold)

                tvPrebufferSection

                tvCacheSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, TVLayout.rowVerticalPadding)
        }
        .background(Color.Brand.primary.ignoresSafeArea())
        .navigationTitle("")
        .onAppear { send(.viewDidAppear) }
    }

    private var tvPrebufferSection: some View {
        VStack(alignment: .leading, spacing: TVLayout.sectionHeaderSpacing) {
            Text(String.localised("video.prebuffer.header", table: .videos))
                .font(.title3)
                .fontWeight(.semibold)

            Toggle(isOn: Binding(store.withState { $0.$prebufferEnabled })) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String.localised("video.prebuffer.tv.title", table: .videos))
                    Text(String.localised("video.prebuffer.tv.subtitle", table: .videos))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            // Reachable: the cache section's controls follow it.
            Text(String.localised("video.prebuffer.tv.footer", table: .videos))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    /// Explanatory text and the read-only stats sit above the controls:
    /// the focus engine only scrolls to reveal focusable views, so text
    /// below the last control (or below a disabled Clear button) could
    /// never be scrolled into view.
    private var tvCacheSection: some View {
        VStack(alignment: .leading, spacing: TVLayout.sectionHeaderSpacing) {
            Text(String.localised("video.cache.header", table: .videos))
                .font(.title3)
                .fontWeight(.semibold)

            Text(String.localised("video.cache.footer", table: .videos))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Text(String.localised("video.cache.totalSize", table: .videos))
                Spacer()
                Text(formattedSize)
                    .foregroundStyle(Color.Brand.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Text(String.localised("video.cache.videos", table: .videos))
                Spacer()
                Text("\(store.entryCount)")
                    .foregroundStyle(Color.Brand.secondary)
            }
            .accessibilityElement(children: .combine)

            Picker(
                String.localised("video.cache.sizeLimit", table: .videos),
                selection: Binding(store.withState { $0.$cacheSizeLimitBytes })
            ) {
                ForEach(PlaybackCache.cacheSizeLimitPresetsBytes, id: \.self) { value in
                    Text(Self.cacheLimitLabel(for: value)).tag(value)
                }
            }

            Button(role: .destructive) {
                send(.clearCacheTapped)
            } label: {
                Text(String.localised("video.cache.clear", table: .videos))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .disabled(store.entryCount == 0)
        }
    }
    #endif

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: store.totalSize, countStyle: .file)
    }

    private static func cacheLimitLabel(for bytes: Int) -> String {
        guard bytes > 0 else {
            return String.localised("video.cache.sizeLimit.unlimited", table: .videos)
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
#endif
