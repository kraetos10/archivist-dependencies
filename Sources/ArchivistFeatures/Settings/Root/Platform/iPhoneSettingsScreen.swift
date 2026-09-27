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
            case .history(let store):
                HistoryScreen(store: store)
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

    private var settingsList: some View {
        List {
            ActiveTaskView(store: store.scope(state: \.activeTask, action: \.activeTask))

            ActiveDeviceDownloadView()

            Section {
                Button {
                    send(.downloadsTapped)
                } label: {
                    SettingsNavigationRow(
                        icon: "arrow.down.circle",
                        title: String.localised("settings.queue", table: .settings)
                    )
                }

                Button {
                    send(.statsTapped)
                } label: {
                    SettingsNavigationRow(
                        icon: "chart.bar",
                        title: String.localised("settings.stats", table: .settings)
                    )
                }

                Button {
                    send(.historyTapped)
                } label: {
                    SettingsNavigationRow(
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
                .disabled(store.isRescanDisabled)
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
                if let port = store.portDescription {
                    LabeledContent(String.localised("settings.port", table: .settings)) {
                        Text(port)
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
                LabeledContent(String.localised("settings.connection", table: .settings)) {
                    Text(store.connectionDescription)
                        .foregroundStyle(Color.Brand.secondary)
                }
            } header: {
                Text(String.localised("settings.serverInfo", table: .settings))
            }

            Section {
                Toggle(
                    String.localised("video.autoplay", table: .videos),
                    isOn: $store.autoPlayEnabled.sending(\.view.autoPlayToggled)
                )
                Toggle(
                    String.localised("video.autoplayPlaylist", table: .videos),
                    isOn: $store.autoPlayPlaylist.sending(\.view.autoPlayPlaylistToggled)
                )
            } header: {
                Text(String.localised("video.autoplaySection", table: .videos))
            }

            ThemePickerSection()

            if let supportURL = store.supportURL {
                Section {
                    Link(destination: supportURL) {
                        HStack {
                            Image(systemName: "heart")
                                .foregroundStyle(Color.Accent.dark)
                                .accessibilityHidden(true)
                            Text(String.localised("settings.support", table: .settings))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Color.Brand.secondary)
                                .accessibilityHidden(true)
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
                    SettingsNavigationRow(
                        icon: "shippingbox",
                        title: String.localised("settings.thirdPartyLibraries", table: .settings)
                    )
                }
            } header: {
                Text(String.localised("settings.about", table: .settings))
            }

            Section {
                if let logURL = store.diagnosticLogURL {
                    ShareLink(item: logURL) {
                        Label(
                            String.localised("settings.diagnostics.shareLogs", table: .settings),
                            systemImage: "square.and.arrow.up"
                        )
                        .foregroundStyle(Color.Text.primary)
                    }
                }
                Button(role: .destructive) {
                    send(.clearDiagnosticLogsTapped)
                } label: {
                    Label(
                        String.localised("settings.diagnostics.clearLogs", table: .settings),
                        systemImage: "trash"
                    )
                }
            } header: {
                Text(String.localised("settings.diagnostics", table: .settings))
            } footer: {
                Text(String.localised("settings.diagnostics.footer", table: .settings))
            }

            Section {
                Button(role: .destructive) {
                    send(.logoutTapped)
                } label: {
                    Label(
                        String.localised("settings.logout", table: .settings),
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
            }

            Section {
            } footer: {
                Text(String.localised("settings.versionFooter \(store.appVersion)", table: .settings))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .refreshable { await send(.pullToRefreshTriggered).finish() }
        .scrollContentBackground(.hidden)
        .background(Color.Brand.primary)
        .navigationTitle(String.localised("generic.settings", table: .generic))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { send(.viewDidAppear) }
    }
}

/// A settings row that pushes another screen.
private struct SettingsNavigationRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.Accent.dark)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Color.Text.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.Brand.secondary)
                .accessibilityHidden(true)
        }
    }
}
#endif
