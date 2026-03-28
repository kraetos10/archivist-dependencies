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
                Button { send(.downloadsTapped) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                        Text(String.localised("settings.queue", table: .settings))
                    }
                    .padding(.vertical, 8)
                }

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

                Button {
                    send(.reAuthTapped)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 16) {
                            if store.isReAuthenticating {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(String.localised("settings.refreshSession", table: .settings))
                        }
                        Text(String.localised("settings.refreshSessionSubtitle", table: .settings))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .disabled(store.isReAuthenticating)
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
                        Text("\(port)")
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
                Toggle(String.localised("video.autoplay", table: .videos), isOn: $store.autoPlayEnabled)
                Toggle(String.localised("video.autoplayPlaylist", table: .videos), isOn: $store.autoPlayPlaylist)
                Toggle(isOn: $store.useVLCPlayer) {
                    Text(String.localised("video.useVLCPlayer", table: .videos))
                    Text(String.localised("video.useVLCPlayerSubtitle", table: .videos))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button { send(.playbackCacheTapped) } label: {
                    HStack {
                        Image(systemName: "externaldrive.badge.timemachine")
                            .foregroundStyle(Color.Accent.dark)
                        Text(String.localised("video.cache.row", table: .videos))
                    }
                }
                Toggle(
                    String.localised("settings.checkForChannelUpdates", table: .settings),
                    isOn: $store.checkForChannelUpdates
                )
            } header: {
                Text(String.localised("video.playback", table: .videos))
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
