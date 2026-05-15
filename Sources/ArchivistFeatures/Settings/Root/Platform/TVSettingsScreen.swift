#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: SettingsReducer.self)
public struct TVSettingsScreen: View {
    @Bindable public var store: StoreOf<SettingsReducer>

    public init(store: StoreOf<SettingsReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            settingsList
        } destination: { store in
            switch store.case {
            case .downloads(let store):
                DownloadsScreen(store: store)
            case .stats(let store):
                StatsScreen(store: store)
            case .history(let store):
                HistoryScreen(store: store)
            case .playbackCache(let store):
                PlaybackCacheScreen(store: store)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                TVVideoDetailScreen(store: detailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
    }

    @ViewBuilder
    private var settingsList: some View {
        List {
            ActiveTaskView(store: store.scope(state: \.activeTask, action: \.activeTask))

            Section {
                Button { send(.statsTapped) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "chart.bar")
                        Text(String.localised("settings.stats", table: .settings))
                    }
                    .padding(.vertical, 8)
                }

                Button { send(.historyTapped) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(String.localised("settings.history", table: .settings))
                    }
                    .padding(.vertical, 8)
                }

                Button { send(.playbackCacheTapped) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.timemachine")
                        Text(String.localised("video.cache.title", table: .videos))
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                Button {
                    send(.rescanSubscriptionsTapped)
                } label: {
                    HStack(spacing: 16) {
                        if store.isRescanningSubscriptions {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(String.localised("settings.rescanSubscriptions", table: .settings))
                    }
                    .padding(.vertical, 8)
                }
                .disabled(store.isRescanningSubscriptions || store.activeTask.activeDownload != nil)
            } header: {
                Text(String.localised("generic.actions", table: .generic))
            }

            Section {
                LabeledContent(String.localised("settings.server", table: .settings)) {
                    Text(store.serverConfig.hostname)
                        .foregroundStyle(.secondary)
                }
                if let port = store.serverConfig.port {
                    LabeledContent(String.localised("settings.port", table: .settings)) {
                        Text(String(port))
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent(String.localised("settings.connection", table: .settings)) {
                    Text(store.serverConfig.useHTTP ? "HTTP" : "HTTPS")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String.localised("settings.serverInfo", table: .settings))
            }

            Section {
                Toggle(String.localised("video.autoplay", table: .videos), isOn: Binding(store.withState { $0.$autoPlayEnabled }))
                Toggle(String.localised("video.autoplayPlaylist", table: .videos), isOn: Binding(store.withState { $0.$autoPlayPlaylist }))
            } header: {
                Text(String.localised("video.autoplaySection", table: .videos))
            }

            Section {
                Button(role: .destructive) {
                    send(.logoutTapped)
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(String.localised("settings.logout", table: .settings))
                    }
                }
            }

            Section {
            } footer: {
                Text(appVersionString)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("")
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Archivist v\(version) (\(build))"
    }
}
#endif
