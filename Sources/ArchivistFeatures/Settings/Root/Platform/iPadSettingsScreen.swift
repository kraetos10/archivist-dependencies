#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: SettingsReducer.self)
public struct iPadSettingsScreen: View {
    @Bindable public var store: StoreOf<SettingsReducer>

    public init(store: StoreOf<SettingsReducer>) {
        self.store = store
    }

    public var body: some View {
        List(selection: $store.selectedDetail) {
            ActiveTaskView(store: store.scope(state: \.activeTask, action: \.activeTask))

            ActiveDeviceDownloadView()

            Section {
                NavigationLink(value: SettingsDetail.queue) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color.Accent.dark)
                        Text(String(localized: "Queue"))
                    }
                }

                NavigationLink(value: SettingsDetail.stats) {
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundStyle(Color.Accent.dark)
                        Text(String(localized: "Stats"))
                    }
                }

                NavigationLink(value: SettingsDetail.deviceDownloads) {
                    HStack {
                        Image(systemName: "arrow.down.to.line")
                            .foregroundStyle(Color.Accent.dark)
                        Text(String(localized: "Device Downloads"))
                    }
                }

                NavigationLink(value: SettingsDetail.history) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color.Accent.dark)
                        Text(String(localized: "History"))
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
                Text(String(localized: "Actions"))
            }

            Section {
                HStack {
                    Text(String(localized: "Server"))
                    Spacer()
                    Text(store.serverConfig.hostname)
                        .foregroundStyle(Color.Brand.secondary)
                }
                if let port = store.serverConfig.port {
                    HStack {
                        Text(String(localized: "Port"))
                        Spacer()
                        Text("\(port)")
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
                HStack {
                    Text(String(localized: "Connection"))
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
                        Text(String(localized: "Refresh Session"))
                        Spacer()
                        if store.isReAuthenticating {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(store.isReAuthenticating)
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
        }
        .refreshable { await send(.pullToRefreshTriggered).finish() }
        .scrollContentBackground(.hidden)
        .background(Color.Brand.primary)
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Brand.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }
}
#endif
