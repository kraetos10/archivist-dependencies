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
        NavigationStack {
            List {
                ActiveTaskView(store: store.scope(state: \.activeTask, action: \.activeTask))

                Section {
                    NavigationLink {
                        DownloadsScreen(store: store.scope(state: \.downloads, action: \.downloads))
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text(String(localized: "Queue"))
                        }
                    }

                    NavigationLink {
                        StatsScreen(store: store.scope(state: \.stats, action: \.stats))
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar")
                            Text(String(localized: "Stats"))
                        }
                    }

                    NavigationLink {
                        HistoryScreen(store: store.scope(state: \.history, action: \.history))
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text(String(localized: "History"))
                        }
                    }
                }

                Section {
                    Button {
                        send(.rescanSubscriptionsTapped)
                    } label: {
                        HStack {
                            if store.isRescanningSubscriptions {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(String(localized: "Rescan Subscriptions"))
                        }
                    }
                    .disabled(store.isRescanningSubscriptions || store.activeTask.activeDownload != nil)
                } header: {
                    Text(String(localized: "Actions"))
                }

                Section {
                    HStack {
                        Text(String(localized: "Server"))
                        Spacer()
                        Text(store.serverConfig.hostname)
                            .foregroundStyle(.secondary)
                    }
                    if let port = store.serverConfig.port {
                        HStack {
                            Text(String(localized: "Port"))
                            Spacer()
                            Text("\(port)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text(String(localized: "Connection"))
                        Spacer()
                        Text(store.serverConfig.useHTTP ? "HTTP" : "HTTPS")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "Server Info"))
                }

                Section {
                    Toggle(String(localized: "Autoplay"), isOn: $store.autoPlayEnabled)
                } header: {
                    Text(String(localized: "Playback"))
                }

                Section {
                    Button(role: .destructive) {
                        send(.logoutTapped)
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(String(localized: "Logout"))
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
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                TVVideoDetailScreen(store: detailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Archivist v\(version) (\(build))"
    }
}
#endif
