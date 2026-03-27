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
        NavigationStack {
            List {
                ActiveTaskView(store: store.scope(state: \.activeTask, action: \.activeTask))

                ActiveDeviceDownloadView()

                Section {
                    NavigationLink {
                        DownloadsScreen(store: store.scope(state: \.downloads, action: \.downloads))
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(Color.Accent.dark)
                            Text(String.localised("settings.queue", table: .settings))
                        }
                    }

                    NavigationLink {
                        StatsScreen(store: store.scope(state: \.stats, action: \.stats))
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundStyle(Color.Accent.dark)
                            Text(String.localised("settings.stats", table: .settings))
                        }
                    }

                    NavigationLink {
                        DeviceDownloadsScreen(store: store.scope(state: \.deviceDownloads, action: \.deviceDownloads))
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.to.line")
                                .foregroundStyle(Color.Accent.dark)
                            Text(String.localised("video.deviceDownloads", table: .videos))
                        }
                    }

                    NavigationLink {
                        HistoryScreen(store: store.scope(state: \.history, action: \.history))
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Color.Accent.dark)
                            Text(String.localised("settings.history", table: .settings))
                        }
                    }
                }

                Section {
                    LoadingButton(
                        title: LocalizedStringResource("rescanSubscriptions"),
                        isLoading: store.isRescanningSubscriptions
                    ) {
                        send(.rescanSubscriptionsTapped)
                    }
                    .disabled(store.isRescanningSubscriptions || store.activeTask.activeDownload != nil)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text(String.localised("generic.actions"))
                }

                Section {
                    HStack {
                        Text(String.localised("settings.server", table: .settings))
                        Spacer()
                        Text(store.serverConfig.hostname)
                            .foregroundStyle(Color.Brand.secondary)
                    }
                    if let port = store.serverConfig.port {
                        HStack {
                            Text(String.localised("settings.port", table: .settings))
                            Spacer()
                            Text("\(port)")
                                .foregroundStyle(Color.Brand.secondary)
                        }
                    }
                    HStack {
                        Text(String.localised("settings.connection", table: .settings))
                        Spacer()
                        Text(store.serverConfig.useHTTP ? "HTTP" : "HTTPS")
                            .foregroundStyle(Color.Brand.secondary)
                    }

                    Button {
                        send(.reAuthTapped)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.Accent.dark)
                            Text(String.localised("settings.refreshSession", table: .settings))
                            Spacer()
                            if store.isReAuthenticating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(store.isReAuthenticating)
                } header: {
                    Text(String.localised("settings.serverInfo", table: .settings))
                }

                Section {
                    Toggle(String.localised("video.autoplay", table: .videos), isOn: $store.autoPlayEnabled)
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
            .refreshable { await send(.pullToRefreshTriggered).finish() }
            .scrollContentBackground(.hidden)
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("generic.settings"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }
    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Archivist v\(version) (\(build))"
    }
}
#endif
