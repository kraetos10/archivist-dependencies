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
                            .accessibilityHidden(true)
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
                .disabled(store.isRescanDisabled)
            } header: {
                Text(String.localised("generic.actions", table: .generic))
            }

            Section {
                LabeledContent(String.localised("settings.server", table: .settings)) {
                    Text(store.serverConfig.hostname)
                        .foregroundStyle(.secondary)
                }
                if let port = store.portDescription {
                    LabeledContent(String.localised("settings.port", table: .settings)) {
                        Text(port)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent(String.localised("settings.connection", table: .settings)) {
                    Text(store.connectionDescription)
                        .foregroundStyle(.secondary)
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

            // Above Log Out rather than in a trailing footer: the list only
            // scrolls to reveal focusable rows, so text after the last
            // button never came into view.
            Section {
                LabeledContent(String.localised("settings.appVersion", table: .settings)) {
                    Text(store.appVersion)
                        .foregroundStyle(.secondary)
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
        }
        .navigationTitle("")
    }
}
#endif
