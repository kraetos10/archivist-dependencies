#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: SettingsReducer.self)
public struct iPhoneSettingsScreen: View {
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
            case .deviceDownloads(let store):
                DeviceDownloadsScreen(store: store)
            case .history(let store):
                HistoryScreen(store: store)
            case .playbackCache(let store):
                PlaybackCacheScreen(store: store)
            case .thirdPartyLibraries(let store):
                ThirdPartyLibrariesScreen(store: store)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }

    @ViewBuilder
    private var settingsList: some View {
        List {
            ActiveTaskView(store: store.scope(state: \.activeTask, action: \.activeTask))

            ActiveDeviceDownloadView()

            Section {
                Button {
                    send(.statsTapped)
                } label: {
                    settingsRow(
                        icon: "chart.bar",
                        title: String.localised("settings.stats", table: .settings)
                    )
                }

                Button {
                    send(.deviceDownloadsTapped)
                } label: {
                    settingsRow(
                        icon: "arrow.down.to.line",
                        title: String.localised("video.deviceDownloads", table: .videos)
                    )
                }

                Button {
                    send(.historyTapped)
                } label: {
                    settingsRow(
                        icon: "clock.arrow.circlepath",
                        title: String.localised("settings.history", table: .settings)
                    )
                }
            }

            Section {
                LoadingButton(
                    title: String.localised("settings.rescanSubscriptions", table: .settings),
                    isLoading: store.isRescanningSubscriptions
                ) {
                    send(.rescanSubscriptionsTapped)
                }
                .disabled(store.isRescanningSubscriptions || store.activeTask.activeDownload != nil)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text(String.localised("generic.actions", table: .generic))
            }

            Section {
                LabeledContent(String.localised("settings.server", table: .settings)) {
                    Text(store.serverConfig.hostname)
                        .foregroundStyle(Color.Brand.secondary)
                }
                if let port = store.serverConfig.port {
                    LabeledContent(String.localised("settings.port", table: .settings)) {
                        Text(String(port))
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
                LabeledContent(String.localised("settings.connection", table: .settings)) {
                    Text(store.serverConfig.useHTTP ? "HTTP" : "HTTPS")
                        .foregroundStyle(Color.Brand.secondary)
                }
            } header: {
                Text(String.localised("settings.serverInfo", table: .settings))
            }

            Section {
                Toggle(String.localised("video.autoplay", table: .videos), isOn: $store.autoPlayEnabled)
                Toggle(String.localised("video.autoplayPlaylist", table: .videos), isOn: $store.autoPlayPlaylist)
            } header: {
                Text(String.localised("video.autoplaySection", table: .videos))
            }

            Section {
                Button {
                    send(.playbackCacheTapped)
                } label: {
                    settingsRow(
                        icon: "externaldrive.badge.timemachine",
                        title: String.localised("video.cache.row", table: .videos)
                    )
                }
                Toggle(
                    String.localised("video.forceHTTP", table: .videos),
                    isOn: $store.forceHTTPPlayback
                )
            } header: {
                Text(String.localised("video.playback", table: .videos))
            } footer: {
                Text(String.localised("video.forceHTTP.footer", table: .videos))
            }

            if let supportURL = store.supportURL {
                Section {
                    Link(destination: supportURL) {
                        HStack {
                            Image(systemName: "heart")
                                .foregroundStyle(Color.Accent.dark)
                            Text(String.localised("settings.support", table: .settings))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color.Brand.secondary)
                        }
                    }
                } header: {
                    Text(String.localised("settings.supportHeader", table: .settings))
                }
            }

            Section {
                Button {
                    send(.thirdPartyLibrariesTapped)
                } label: {
                    settingsRow(
                        icon: "shippingbox",
                        title: String.localised("settings.thirdPartyLibraries", table: .settings)
                    )
                }
            } header: {
                Text(String.localised("settings.about", table: .settings))
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
        .refreshable { send(.pullToRefreshTriggered) }
        .scrollContentBackground(.hidden)
        .background(Color.Brand.primary)
        .navigationTitle(String.localised("generic.settings", table: .generic))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.Accent.dark)
            Text(title)
                .foregroundStyle(Color.Text.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.Brand.secondary)
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Archivist v\(version) (\(build))"
    }
}
#endif
